import '../../domain/mail_action.dart';
import '../../domain/result.dart';
import '../oauth/oauth_failed.dart';
import 'graph_failure.dart';
import 'graph_http.dart';
import 'graph_place.dart';

/// Letto and Stella on Graph: `PATCH /me/messages/{id}` conditioned on the etag read with the message (`If-Match`).
class GraphFlags(final GraphHttp _graph) {
  /// Writes the flag [action] wants over [at]; false when Graph answers 412: the message changed since the read
  /// (any change moves the etag, not only this attribute's), so the caller reads it again.
  Future<bool> write(GraphPlace at, MailAction action) async {
    final body = switch (action) {
      MarkRead() || MarkUnread() => {'isRead': action.wanted},
      Star() || Unstar() => {
        'flag': {'flagStatus': action.wanted == true ? 'flagged' : 'notFlagged'},
      },
      _ => throw ArgumentError.value(action, 'action', 'not a flag'),
    };
    try {
      await _graph.send(
        'PATCH',
        'messages/${at.id}',
        body: body,
        headers: {if (at.etag.isNotEmpty) 'If-Match': at.etag},
      );
      return true;
    } on OAuthFailed catch (e) {
      if (e.failure case RejectedFailure(reason: graphPreconditionFailed)) return false;
      rethrow;
    }
  }
}
