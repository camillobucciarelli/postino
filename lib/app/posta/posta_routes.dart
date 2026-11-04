import 'package:routefly/routefly.dart';

import '../../main.dart' show routePaths;

/// What a `/posta` URI shows: the list, and the Conversazione or the Bozza open beside it.
class PostaRoute {
  const PostaRoute._({
    required this.list,
    required this.open,
    required this.draft,
    required this.accountId,
    required this.labelId,
  });

  /// Reads [uri]; [isLayout]: the URI is the layout's own, with no child route. [last] is the last list shown.
  factory PostaRoute.parse(Uri uri, {required bool isLayout, String? last}) {
    final seg = isLayout ? const <String>[] : uri.pathSegments;
    // (account, conversation) or (account, Message-ID): `pathSegments` decodes the percent-encoding.
    final open = seg.length > 3 && seg[2] == 'conversazione'
        ? (seg[1], seg[3])
        : null;
    final draft = seg.length > 3 && seg[2] == 'bozza' ? (seg[1], seg[3]) : null;
    final detail = open ?? draft;
    // Opened from the Posta unificata or from a list of its Account; else (deep link) its inbox.
    final list = detail == null
        ? uri.path
        : last != null &&
              (last == routePaths.posta.path ||
                  Uri.parse(last).pathSegments[1] == detail.$1)
        ? last
        : routePaths.posta.$accountId.path.changes({'accountId': detail.$1});
    // /posta/<account>[/etichetta/<label>]: the docked drawer reads its selection from the list.
    final ls = Uri.parse(list).pathSegments;
    return PostaRoute._(
      list: list,
      open: open,
      draft: draft,
      accountId: ls.length > 1 ? ls[1] : null,
      labelId: ls.length > 3 ? ls[3] : null,
    );
  }

  /// The path of the list shown.
  final String list;

  /// (account, conversation) of the open Conversazione.
  final (String, String)? open;

  /// (account, Message-ID) of the Bozza open in the composer.
  final (String, String)? draft;

  /// The Account and Etichetta of [list].
  final String? accountId, labelId;

  /// What opens beside the list: the Conversazione or the Bozza.
  (String, String)? get detail => open ?? draft;
}

/// Opens the composer of a Bozza.
void openDraft(String accountId, String messageId) => Routefly.navigate(
  routePaths.posta.$accountId.bozza.$messageId.changes({
    'accountId': accountId,
    'messageId': Uri.encodeComponent(messageId),
  }),
);

/// Opens a Conversazione.
void openConversation(String accountId, String conversationId) =>
    Routefly.navigate(
      routePaths.posta.$accountId.conversazione.$conversationId.changes({
        'accountId': accountId,
        'conversationId': conversationId,
      }),
    );
