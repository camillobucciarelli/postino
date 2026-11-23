import 'dart:async';

import 'package:routefly/routefly.dart';

import '../../features/posta/domain/inbox_sections.dart';
import '../../main.dart' show routePaths;

/// What a `/posta` URI shows: the list, and the Conversazione or the Bozza open beside it.
class const PostaRoute._({
  /// The path of the list shown.
  required final String list,

  /// (account, conversation) of the open Conversazione.
  required final (String, String)? open,

  /// (account, Message-ID) of the Bozza open in the composer.
  required final (String, String)? draft,

  /// The Account and Etichetta of [list].
  required final String? accountId,
  required final String? labelId,
}) {
  /// Reads [uri]; [isLayout]: the URI is the layout's own, with no child route. [last] is the last list shown.
  factory PostaRoute.parse(Uri uri, {required bool isLayout, String? last}) {
    final seg = isLayout ? const <String>[] : uri.pathSegments;
    // (account, conversation) or (account, Message-ID): `pathSegments` decodes the percent-encoding.
    final open = seg.length > 3 && seg[2] == 'conversazione' ? (seg[1], seg[3]) : null;
    final draft = seg.length > 3 && seg[2] == 'bozza' ? (seg[1], seg[3]) : null;
    final detail = open ?? draft;
    // Opened from the Posta unificata or from a list of its Account; else (deep link) its inbox.
    final list = detail == null
        ? uri.path
        : last != null && (last == routePaths.posta.path || Uri.parse(last).pathSegments[1] == detail.$1)
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

  /// What opens beside the list: the Conversazione or the Bozza.
  (String, String)? get detail => open ?? draft;
}

/// The path of an Etichetta's list; the id is percent-encoded, so a folder `cartella:Lavoro/Progetti` stays one segment.
String labelPath(String accountId, String labelId) => routePaths.posta.$accountId.etichetta.$labelId.changes({
  'accountId': accountId,
  'labelId': Uri.encodeComponent(labelId),
});

/// Opens the composer of a Bozza.
void openDraft(String accountId, String messageId) => Routefly.navigate(
  routePaths.posta.$accountId.bozza.$messageId.changes({
    'accountId': accountId,
    'messageId': Uri.encodeComponent(messageId),
  }),
);

/// Opens a Conversazione.
void openConversation(String accountId, String conversationId) => Routefly.navigate(
  routePaths.posta.$accountId.conversazione.$conversationId.changes({
    'accountId': accountId,
    'conversationId': conversationId,
  }),
);

/// Opens the search over the Posta view (#205), in [accountId] only, or in every Account: back pops to the view.
/// The scope goes as the route's argument: a pushed route does not carry its query string to `Routefly.query`.
/// [labelId] is the Etichetta of the view, passed only for the Cestino: it searches the Cestino alone.
void openSearch({String? accountId, String? labelId}) =>
    unawaited(Routefly.push<void>(routePaths.cerca, arguments: (accountId, labelId)));

/// «Mostra tutti» of [section] of the posta in arrivo (#366), of [accountId] or of the Posta unificata: back pops
/// to the view. The scope goes as the route's argument, as for the search.
void openSection(InboxSection section, {String? accountId}) =>
    unawaited(Routefly.push<void>(routePaths.sezione, arguments: (section, accountId)));
