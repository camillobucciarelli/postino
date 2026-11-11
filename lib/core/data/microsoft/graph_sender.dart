import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../domain/result.dart';
import '../oauth/oauth_failed.dart';
import 'graph_drafts.dart';
import 'graph_http.dart';
import 'graph_lookup.dart';

/// Sending on Graph (#183, `invio-posta-per-provider.md` §2 and §6): `sendMail` takes the whole MIME (base64), answers
/// 202 without an id and files the copy in Posta inviata by itself, no APPEND. Posta inviata is searched by
/// Message-ID first, so a send whose answer was lost is not submitted again; the Bozza with the same Message-ID goes
/// last. Failures are thrown as [OAuthFailed].
class GraphSender(
  final GraphHttp _graph,
  final GraphLookup _lookup,
  final GraphDrafts _drafts,
  final Future<void> Function(Duration) _sleep,
) {
  static const _sent = 'sentitems';

  /// How long Graph may take, after a 202, to show the message in Posta inviata: a retry waits it before it decides
  /// the message did not go.
  // ponytail: a guess; measure it on the Outlook.com Account (#203).
  static const sentLag = Duration(seconds: 10);

  /// Message-IDs whose `sendMail` ended without an answer in this run: they may have gone, the retry waits and looks.
  /// Memory of this adapter only; a restart looks at once, and the 202 recorded by `onSubmitted` covers the rest.
  final _unanswered = <String>{};

  /// Sends [raw], whose Message-ID is [messageId]; the id of its copy in Posta inviata, or [messageId] while Graph
  /// has not filed it yet (the next sync brings the real one). With [submitted] (the 202 already came) `sendMail`
  /// is not called again; `onSubmitted` runs right after the 202.
  Future<String> send(
    String messageId,
    String raw, {
    bool submitted = false,
    Future<void> Function()? onSubmitted,
  }) async {
    var id = await _find(messageId);
    if (id == null && (submitted || _unanswered.contains(messageId))) {
      await _sleep(sentLag);
      id = await _find(messageId);
    }
    if (id == null && !submitted) {
      _unanswered.add(messageId);
      await _graph.send('POST', 'sendMail', text: base64.encode(utf8.encode(raw)));
      _unanswered.remove(messageId);
      try {
        await onSubmitted?.call();
      } on Object catch (e) {
        // The message went: recording it is only the retry's shortcut.
        debugPrint('[graph] submission of $messageId not recorded, $e');
      }
      id = await _find(messageId);
    }
    // Best effort: the message went, a Bozza left behind is deleted by the next save or by hand.
    try {
      await _drafts.delete(messageId);
    } on OAuthFailed catch (e) {
      if (e.failure is! NotFoundFailure) debugPrint('[graph] draft of sent $messageId not deleted, ${e.failure}');
    }
    return id ?? messageId;
  }

  Future<String?> _find(String messageId) async => (await _lookup.idsIn(_sent, messageId)).firstOrNull;
}
