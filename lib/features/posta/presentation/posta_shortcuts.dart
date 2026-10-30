import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';

/// What a shortcut of the Posta views does. #37 and the action tickets add their values here.
enum PostaAction { next, previous }

/// One key and what it does. [listOnly]: only while the focus is on the list (the arrows),
/// elsewhere — in a Conversazione — they belong to scrolling.
class PostaShortcut {
  const PostaShortcut(this.key, this.action, {this.listOnly = false});
  final LogicalKeyboardKey key;
  final PostaAction action;
  final bool listOnly;
}

/// The one table key -> action of the Posta views (ADR 0014); a test checks that no key appears twice.
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
];

/// What the shortcuts act on: the list of Conversazioni, which plugs itself in.
class ListCursor {
  /// Moves the cursor by one row (+1 next, -1 previous).
  void Function(int delta)? move;

  /// Whether the focus is on the list and the list is the one in front.
  bool Function()? listFocused;
}

class PostaIntent extends Intent {
  const PostaIntent(this.shortcut);
  final PostaShortcut shortcut;
}

/// Binds [postaShortcuts] to [cursor] for everything below it. Ignored while the focus is in a
/// text field, so the letters are typed (ADR 0014).
class PostaShortcuts extends StatelessWidget {
  const PostaShortcuts({super.key, required this.cursor, required this.child});

  final ListCursor cursor;
  final Widget child;

  @override
  Widget build(BuildContext context) => Shortcuts(
    shortcuts: {
      for (final s in postaShortcuts) SingleActivator(s.key): PostaIntent(s),
    },
    child: Actions(actions: {PostaIntent: _PostaAction(cursor)}, child: child),
  );
}

class _PostaAction extends Action<PostaIntent> {
  _PostaAction(this.cursor);
  final ListCursor cursor;

  @override
  bool isEnabled(PostaIntent intent) {
    final focus = primaryFocus?.context;
    if (focus == null ||
        focus.findAncestorWidgetOfExactType<EditableText>() != null) {
      return false;
    }
    return !intent.shortcut.listOnly || (cursor.listFocused?.call() ?? false);
  }

  @override
  Object? invoke(PostaIntent intent) {
    cursor.move?.call(switch (intent.shortcut.action) {
      PostaAction.next => 1,
      PostaAction.previous => -1,
    });
    return null;
  }
}
