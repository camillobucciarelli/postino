import 'package:injectable/injectable.dart';

import '../../domain/auto_label_classifier.dart';
import '../../domain/auto_labels_repository.dart';
import '../../domain/embedding_text.dart';
import '../../domain/error_log.dart';
import '../../domain/message.dart';
import '../../domain/text_embedder.dart';
import '../postino_database.dart';
import '../row_mappers.dart';

/// The Etichettatura automatica (#109, ADR 0015): the new mail of an incremental sync gets at most one of the
/// Account's Etichette automatiche, the closest prototype by cosine. Only mail that arrived after the Etichetta was
/// switched on, and without an Etichetta dell'utente; the Etichetta goes through the offline queue.
@lazySingleton
class AutoLabeler(
  final PostinoDatabase _db,
  final AutoLabelsRepository _config,
  final TextEmbedder _embedder,
  final ErrorLog _log,
) {
  /// Classifies [fresh] (stored already, [bodies] those of its sync) and queues the Etichette; true when it queued
  /// any, so the queue needs a replay. Never throws: a failure is in the error log, and a failed mail does not stop
  /// the others.
  Future<bool> queueAutoLabels(String accountId, List<Message> fresh, Map<String, MessageBody> bodies) async {
    var queued = false;
    try {
      // By Etichetta id: the description and the activation; one gone from the Provider takes no part.
      final active = {
        for (final MapEntry(:key, :value) in (await _config.watch(accountId).first).entries)
          if (value case (automatic: true, :final description, activatedAt: final at?))
            key: (description: description, at: at),
      };
      if (active.isEmpty) return false;
      final names = {for (final l in await _db.labelsDao.all(accountId)) l.id: l.name};
      active.removeWhere((id, _) => !names.containsKey(id));
      // Computed once per run: the mail labelled now does not shift the prototypes of the next.
      final prototypes = <String, List<double>?>{};
      for (final m in fresh) {
        final candidates = [
          for (final MapEntry(:key, :value) in active.entries)
            if (m.date.millisecondsSinceEpoch >= value.at) key,
        ];
        if (candidates.isEmpty) continue;
        try {
          final vector = await _embedder.embed(emailEmbeddingText(m, bodies[m.id]));
          // The model is not ready: the next sync's mail will be classified once it is.
          if (vector == null) break;
          // Gone while the model ran (its Account removed, #174, or the message moved): nothing written for it.
          if (!await _db.messagesDao.exists(accountId, m.id)) continue;
          // Saved before the check: a mail the user labels is an example of that Etichetta.
          await _db.messageEmbeddingsDao.save(accountId, m.id, _embedder.modelId, vector);
          if (await _db.intentsDao.hasUserLabel(accountId, m.id)) continue;
          final scored = <String, List<double>>{};
          for (final id in candidates) {
            if (!prototypes.containsKey(id)) {
              prototypes[id] = await _prototype(accountId, id, names[id]!, active[id]!.description);
            }
            if (prototypes[id] case final p?) scored[id] = p;
          }
          // Checked again in the write's transaction: what the user did meanwhile wins.
          if (pickAutoLabel(scored, vector) case final labelId?) {
            queued =
                await _db.intentsDao.queueAutoLabel(accountId, m.id, labelId, activatedAt: active[labelId]!.at) ||
                queued;
          }
        } on Object catch (e, s) {
          _log.record(e, stack: s, context: 'etichettatura $accountId');
        }
      }
    } on Object catch (e, s) {
      _log.record(e, stack: s, context: 'etichettatura $accountId');
    }
    return queued;
  }

  /// The centroid of the Etichetta's examples, or its name and description while it has too few.
  Future<List<double>?> _prototype(String accountId, String labelId, String name, String? description) async {
    final dao = _db.messageEmbeddingsDao;
    final model = _embedder.modelId;
    var examples = await dao.examples(accountId, labelId, model);
    if (examples.length < maxAutoLabelExamples) {
      // The mail already in the Etichetta, before or after the activation, embedded the first time it is needed.
      for (final (m, b) in await dao.unembedded(accountId, labelId, model)) {
        final vector = await _embedder.embed(emailEmbeddingText(messageOf(m), b == null ? null : bodyOf(b)));
        if (vector == null) break;
        await dao.save(accountId, m.id, model, vector);
      }
      examples = await dao.examples(accountId, labelId, model);
    }
    if (examples.length >= minAutoLabelExamples) return centroid(examples);
    return _embedder.embed(labelEmbeddingText(name, description));
  }
}
