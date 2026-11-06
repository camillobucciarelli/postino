import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../../design_system/design_system.dart' show ToggleSidebarIntent;

/// What a shortcut of the Posta views does. #37 and the action tickets add their values here.
enum PostaAction() {
  next,
  previous,
  toggleSidebar,
  write,
  reply,
  replyAll,
  forward,
  labels,
  reportProblem,
  archive,
  delete,
  star,
  markRead,
  markUnread,
}

/// One key and what it does. [listOnly]: only while the focus is on the list (the arrows),
/// elsewhere — in a Conversazione — they belong to scrolling.
/// [command]: with the platform's command key, Cmd on macOS and Ctrl elsewhere; without it, the key bare.
/// [character]: the typed character instead of [key] (null then), on whatever key the layout puts it (`#`).
class const PostaShortcut(
  final LogicalKeyboardKey? key,
  final PostaAction action, {
  final bool listOnly = false,
  final bool command = false,
  final bool shift = false,
  final String? character,

  /// Whether holding the key repeats the action: false for one that starts something (a report), true for moving.
  final bool repeats = true,
}) {
  /// What the registry compares: no two shortcuts may share it.
  Object get chord => (key, character, shift, command);
}

/// The one table key + modifiers -> action of the Posta views (ADR 0014); a test checks that no pair appears twice.
/// Enter and Esc are not here: they are the focused row's activation and the layout's way back.
const postaShortcuts = <PostaShortcut>[
  PostaShortcut(LogicalKeyboardKey.keyJ, PostaAction.next),
  PostaShortcut(LogicalKeyboardKey.keyK, PostaAction.previous),
  PostaShortcut(LogicalKeyboardKey.arrowDown, PostaAction.next, listOnly: true),
  PostaShortcut(LogicalKeyboardKey.arrowUp, PostaAction.previous, listOnly: true),
  PostaShortcut(LogicalKeyboardKey.keyB, PostaAction.toggleSidebar, command: true),
  PostaShortcut(LogicalKeyboardKey.keyC, PostaAction.write),
  PostaShortcut(LogicalKeyboardKey.keyR, PostaAction.reply),
  PostaShortcut(LogicalKeyboardKey.keyA, PostaAction.replyAll),
  PostaShortcut(LogicalKeyboardKey.keyF, PostaAction.forward),
  PostaShortcut(LogicalKeyboardKey.keyL, PostaAction.labels),
  PostaShortcut(LogicalKeyboardKey.keyP, PostaAction.reportProblem, repeats: false),
  PostaShortcut(LogicalKeyboardKey.keyE, PostaAction.archive, repeats: false),
  PostaShortcut(null, PostaAction.delete, character: '#', repeats: false),
  PostaShortcut(LogicalKeyboardKey.keyS, PostaAction.star, repeats: false),
  PostaShortcut(LogicalKeyboardKey.keyI, PostaAction.markRead, shift: true, repeats: false),
  PostaShortcut(LogicalKeyboardKey.keyU, PostaAction.markUnread, shift: true, repeats: false),
];

/// What the shortcuts act on: the list of Conversazioni, which plugs itself in.
class ListCursor() {
  /// Moves the cursor by one row (+1 next, -1 previous).
  void Function(int delta)? move;

  /// Whether the focus is on the list and the list is the one in front.
  bool Function()? listFocused;

  /// Starts a new Bozza (`c`): the «Scrivi» button plugs itself in.
  VoidCallback? write;

  /// Rispondi, Rispondi a tutti and Inoltra (`r`, `a`, `f`) the last message of the open Conversazione (#37):
  /// the Conversazione plugs itself in; idle with none open.
  VoidCallback? reply;
  VoidCallback? replyAll;
  VoidCallback? forward;

  /// Opens the picker of the Etichette of the open Conversazione (`l`, #107): the Conversazione plugs itself in.
  VoidCallback? labels;

  /// Starts the Segnalazione di un problema (`p`, #117): the Posta layout plugs it in.
  VoidCallback? reportProblem;

  /// An Azione (#146: `e`, `#`, `s`, Maiusc+I, Maiusc+U) on the open Conversazione: the Conversazione plugs it in.
  void Function(PostaAction action)? act;

  /// The same on the focused row of the list while no Conversazione is open: the list plugs it in.
  void Function(PostaAction action)? actOnRow;

  /// The open Conversazione (accountId, conversationId) leaves the list (Archivia, Elimina): the selection passes
  /// to the next row, else the previous; false when there is none. The list plugs it in.
  bool Function((String, String) conversation)? leave;
}

class const PostaIntent(final PostaShortcut shortcut) extends Intent {}

/// Binds [postaShortcuts] to [cursor] for everything below it; put it above the sidebar shell,
/// whose [ToggleSidebarIntent] the sidebar shortcut reaches from the focus. Ignored while the focus is in a
/// text field, so the letters are typed (ADR 0014).
class const PostaShortcuts({super.key, required final ListCursor cursor, required final Widget child})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final mac = defaultTargetPlatform == TargetPlatform.macOS;
    return Shortcuts(
      shortcuts: {
        for (final s in postaShortcuts)
          s.character == null
              ? SingleActivator(
                  s.key!,
                  meta: s.command && mac,
                  control: s.command && !mac,
                  shift: s.shift,
                  includeRepeats: s.repeats,
                )
              : CharacterActivator(s.character!, includeRepeats: s.repeats): PostaIntent(
            s,
          ),
      },
      child: Actions(actions: {PostaIntent: _PostaAction(cursor)}, child: child),
    );
  }
}

class _PostaAction(final ListCursor cursor) extends Action<PostaIntent> {
  @override
  bool isEnabled(PostaIntent intent) {
    final focus = primaryFocus?.context;
    if (focus == null || _inTextInput(focus)) return false;
    return !intent.shortcut.listOnly || (cursor.listFocused?.call() ?? false);
  }

  /// Focus inside a text field: an EditableText, or the composer's rich editor (a TextInputClient that is not one).
  static bool _inTextInput(BuildContext focus) {
    var found = false;
    focus.visitAncestorElements((e) {
      found = e is StatefulElement && e.state is TextInputClient;
      return !found;
    });
    return found;
  }

  @override
  Object? invoke(PostaIntent intent) {
    switch (intent.shortcut.action) {
      case PostaAction.next:
        cursor.move?.call(1);
      case PostaAction.previous:
        cursor.move?.call(-1);
      case PostaAction.toggleSidebar:
        // From the focus: the sidebar shell is an ancestor of every focusable.
        final focus = primaryFocus?.context;
        if (focus != null) {
          Actions.maybeInvoke(focus, const ToggleSidebarIntent());
        }
      case PostaAction.write:
        cursor.write?.call();
      case PostaAction.reply:
        cursor.reply?.call();
      case PostaAction.replyAll:
        cursor.replyAll?.call();
      case PostaAction.forward:
        cursor.forward?.call();
      case PostaAction.labels:
        cursor.labels?.call();
      case PostaAction.reportProblem:
        cursor.reportProblem?.call();
      case PostaAction.archive ||
          PostaAction.delete ||
          PostaAction.star ||
          PostaAction.markRead ||
          PostaAction.markUnread:
        (cursor.act ?? cursor.actOnRow)?.call(intent.shortcut.action);
    }
    return null;
  }
}
