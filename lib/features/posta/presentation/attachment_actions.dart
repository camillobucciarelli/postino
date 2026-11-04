import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';

import '../../../core/domain/attachment_repository.dart';
import '../../../core/domain/message.dart';
import '../../../core/domain/platform_services.dart';
import '../../../core/domain/result.dart';

/// The attachments of an open Conversazione (#34): a tap downloads one (unless cached) and opens it in the
/// system's app, its menu saves it; an executable is only saved (#75). Holds the downloads running and the
/// last failures; [onChanged] rebuilds the view, never after [dispose].
class AttachmentActions(final String accountId, final VoidCallback onChanged) {
  bool _disposed = false;

  /// By (message id, attachment id): the downloads running, with their progress and their Annulla,
  /// and why the last one failed.
  final _downloads = <(String, String), ({double done, Completer<void> cancel})>{};

  /// The failure, whether it was a Save As (Riprova repeats the same action) and whether the save itself
  /// failed, not the download before it.
  final _failed = <(String, String), ({Failure failure, bool save, bool saving})>{};

  /// The download of an attachment running, with its progress and its Annulla; null when none.
  ({double done, Completer<void> cancel})? download(String messageId, String attachmentId) =>
      _downloads[(messageId, attachmentId)];

  /// Why the last action on an attachment failed, null when it did not.
  ({Failure failure, bool save, bool saving})? failure(String messageId, String attachmentId) =>
      _failed[(messageId, attachmentId)];

  void _update(VoidCallback change) {
    if (_disposed) return;
    change();
    onChanged();
  }

  /// Cancels the downloads running: nothing is opened or saved after.
  void dispose() {
    _disposed = true;
    for (final d in _downloads.values) {
      if (!d.cancel.isCompleted) d.cancel.complete();
    }
  }

  /// Downloads (unless cached) then opens it in the system's app, or with [save] offers Save As.
  /// [name] is the one the chip shows: the opened copy and Save As carry it too.
  Future<void> start(String messageId, Attachment attachment, String name, {bool save = false}) async {
    final key = (messageId, attachment.id);
    if (_downloads.containsKey(key)) return;
    final cancel = Completer<void>();
    _update(() {
      _downloads[key] = (done: 0, cancel: cancel);
      _failed.remove(key);
    });
    Result<String> r = const Err(UnexpectedFailure('attachment'));
    try {
      r = await GetIt.I<AttachmentRepository>().file(
        accountId,
        messageId,
        Attachment(id: attachment.id, name: name, size: attachment.size, mimeType: attachment.mimeType),
        onProgress: (done) {
          if (_downloads.containsKey(key)) {
            _update(() => _downloads[key] = (done: done, cancel: cancel));
          }
        },
        cancel: cancel.future,
      );
    } finally {
      // Whatever happens, the chip leaves the download: never stuck on it.
      _update(() {
        _downloads.remove(key);
        if (r case Err(:final failure) when failure is! CancelledFailure) {
          _failed[key] = (failure: failure, save: save, saving: false);
        }
      });
    }
    if (_disposed) return;
    if (r case Ok(value: final path)) {
      if (!save) return GetIt.I<LinkOpener>().open(Uri.file(path));
      try {
        await GetIt.I<FileSaver>().save(path, name);
      } on Exception catch (e, s) {
        // A full disk, a folder it may not write to: said on the attachment, Riprova saves again.
        _update(() => _failed[key] = (failure: UnexpectedFailure(e, s), save: true, saving: true));
      }
    }
  }
}
