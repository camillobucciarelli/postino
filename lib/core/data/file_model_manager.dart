import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:file/file.dart';
import 'package:http/http.dart' as http;

import '../domain/model_descriptor.dart';
import '../domain/model_manager.dart';
import '../domain/model_state.dart';
import '../domain/platform_services.dart';
import '../domain/result.dart';

/// The models in [_dir] (#108), downloaded over HTTP: written to `<file>.part` while hashed in the same pass,
/// renamed to their real name only once the SHA-256 matches, so a model under its name is always a whole one.
// ponytail: no resume (HTTP Range); a failed or cancelled download starts again from zero.
class FileModelManager(final http.Client _client, final Connectivity _network, final Directory _dir)
    implements ModelManager {
  /// Lega il gestore alla rete e alla cartella dei modelli.
  this;

  /// States set since launch, by model id; the others are read from the disk.
  final _states = <String, ModelState>{};
  final _changes = StreamController<(String, ModelState)>.broadcast(sync: true);

  /// The downloads in progress, by model id: what aborts each and when it is over.
  final _running = <String, ({Completer<void> abort, Future<void> done})>{};

  @override
  Stream<ModelState> watch(ModelDescriptor model) {
    // ignore: close_sinks, the listener's cancel ends the stream (onCancel stops the changes).
    late final StreamController<ModelState> out;
    StreamSubscription<void>? changes;
    out = StreamController<ModelState>(
      sync: true,
      onListen: () {
        out.add(_state(model));
        changes = _changes.stream.where((c) => c.$1 == model.id).listen((c) => out.add(c.$2));
      },
      onCancel: () => changes?.cancel(),
    );
    return out.stream;
  }

  @override
  Future<void> activate(ModelDescriptor model) async {
    if (_state(model) case ModelAbsent() || ModelFailed()) {
      if (await _network.onWifi()) return download(model);
      _emit(model, ModelAwaitingConfirmation(model.sizeBytes));
    }
  }

  @override
  Future<void> download(ModelDescriptor model) async {
    if (_running[model.id] case final job?) return job.done;
    if (_state(model) is ModelReady) return;
    final abort = Completer<void>();
    final done = _download(model, abort.future);
    _running[model.id] = (abort: abort, done: done);
    try {
      await done;
    } finally {
      _running.remove(model.id);
    }
  }

  Future<void> _download(ModelDescriptor model, Future<void> abort) async {
    var aborted = false;
    unawaited(abort.then((_) => aborted = true));
    final part = _part(model);
    _emit(model, ModelDownloading(0, model.sizeBytes));
    try {
      await _dir.create(recursive: true);
      final response = await _client.send(http.AbortableRequest('GET', model.url, abortTrigger: abort));
      if (response.statusCode != 200) {
        throw http.ClientException('HTTP ${response.statusCode}', model.url);
      }
      Digest? digest;
      final hash = sha256.startChunkedConversion(ChunkedConversionSink.withCallback((d) => digest = d.single));
      final out = await part.open(mode: FileMode.write);
      var received = 0;
      try {
        await for (final chunk in response.stream) {
          await out.writeFrom(chunk);
          hash.add(chunk);
          received += chunk.length;
          _emit(model, ModelDownloading(received, model.sizeBytes));
        }
      } finally {
        await out.close();
      }
      hash.close();
      // Annulla may land after the last chunk: the file is dropped all the same.
      if (aborted) throw http.RequestAbortedException(model.url);
      if (digest.toString() != model.sha256.toLowerCase()) {
        await part.delete();
        _emit(model, const ModelFailed(IntegrityFailure()));
        return;
      }
      final file = await part.rename(_file(model).path);
      _emit(model, ModelReady(file.path));
    } on Exception catch (e, s) {
      try {
        if (part.existsSync()) await part.delete();
      } on FileSystemException {
        // Left behind: the next download overwrites it.
      }
      _emit(model, aborted ? const ModelAbsent() : ModelFailed(UnexpectedFailure(e, s)));
    }
  }

  @override
  Future<void> cancel(ModelDescriptor model) async {
    if (_running[model.id] case final job?) {
      if (!job.abort.isCompleted) job.abort.complete();
      await job.done;
    }
    if (_state(model) case ModelAwaitingConfirmation() || ModelFailed()) {
      _emit(model, const ModelAbsent());
    }
  }

  @override
  Future<int> sizeOnDisk(ModelDescriptor model) async {
    // A missing file is a stat of type notFound, not an exception: a partial file removed meanwhile is fine.
    var total = 0;
    for (final f in [_file(model), _part(model)]) {
      final stat = f.statSync();
      if (stat.type == FileSystemEntityType.file) total += stat.size;
    }
    return total;
  }

  @override
  Future<void> delete(ModelDescriptor model) async {
    await cancel(model);
    final file = _file(model);
    if (file.existsSync()) await file.delete();
    _emit(model, const ModelAbsent());
  }

  ModelState _state(ModelDescriptor model) =>
      _states[model.id] ?? (_file(model).existsSync() ? ModelReady(_file(model).path) : const ModelAbsent());

  void _emit(ModelDescriptor model, ModelState state) {
    _states[model.id] = state;
    _changes.add((model.id, state));
  }

  File _file(ModelDescriptor model) => _dir.childFile(model.fileName);

  File _part(ModelDescriptor model) => _dir.childFile('${model.fileName}.part');
}
