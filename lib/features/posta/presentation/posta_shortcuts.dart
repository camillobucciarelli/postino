import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../../design_system/design_system.dart' show ToggleSidebarIntent;

/// What a shortcut of the Posta views does. #37 and the action tickets add their values here.
enum PostaAction {
  next,
  previous,
  toggleSidebar,
  write,
  reply,
  replyAll,
  forward,
}

/// One key and what it does. [listOnly]: only while the focus is on the list (the arrows),
/// elsewhere — in a Conversazione — they belong to scrolling.
/// [command]: with the platform's command key, Cmd on macOS and Ctrl elsewhere; without it, the key bare.
class PostaShortcut {
  const PostaShortcut(
    this.key,
    this.action, {
    this.listOnly = false,
    this.command = false,
  });
  final LogicalKeyboardKey key;
  final PostaAction action;
  final bool listOnly;
  final bool command;
}

/// The one table key + modifiers -> action of the Posta views (ADR 0014); a test checks that no pair appears twice.
/// Enter and Esc are not here: they are the focused row's activation and the layout's way back.
const postaShortcuts = <PostaShortcut>[
  PostaShortcut(LogicalKeyboardKey.keyJ, PostaAction.next),
  PostaShortcut(LogicalKeyboardKey.keyK, PostaAction.previous),
  PostaShortcut(LogicalKeyboardKey.arrowDown, PostaAction.next, listOnly: true),
  PostaShortcut(
    LogicalKeyboardKey.arrowUp,
    PostaAction.previous,
    listOnly: true,
  ),
  PostaShortcut(
    LogicalKeyboardKey.keyB,
    PostaAction.toggleSidebar,
    command: true,
  ),
  PostaShortcut(LogicalKeyboardKey.keyC, PostaAction.write),
  PostaShortcut(LogicalKeyboardKey.keyR, PostaAction.reply),
  PostaShortcut(LogicalKeyboardKey.keyA, PostaAction.replyAll),
  PostaShortcut(LogicalKeyboardKey.keyF, PostaAction.forward),
];

/// What the shortcuts act on: the list of Conversazioni, which plugs itself in.
class ListCursor {
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
}

class PostaIntent extends Intent {
  const PostaIntent(this.shortcut);
  final PostaShortcut shortcut;
}

/// Binds [postaShortcuts] to [cursor] for everything below it; put it above the sidebar shell,
/// whose [ToggleSidebarIntent] the sidebar shortcut reaches from the focus. Ignored while the focus is in a
/// text field, so the letters are typed (ADR 0014).
class PostaShortcuts extends StatelessWidget {
  const PostaShortcuts({super.key, required this.cursor, required this.child});

  final ListCursor cursor;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final mac = defaultTargetPlatform == TargetPlatform.macOS;
    return Shortcuts(
      shortcuts: {
        for (final s in postaShortcuts)
          SingleActivator(
            s.key,
            meta: s.command && mac,
            control: s.command && !mac,
          ): PostaIntent(
            s,
          ),
      },
      child: Actions(
        actions: {PostaIntent: _PostaAction(cursor)},
        child: child,
      ),
    );
  }
}

class _PostaAction extends Action<PostaIntent> {
  _PostaAction(this.cursor);
  final ListCursor cursor;

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
    }
    return null;
  }
}
