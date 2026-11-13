// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import '../tokens/postino_theme.dart';
import '../tokens/postino_tokens.dart';

/// A modal with [title] (a heading, not selectable) and [child]: the body, ending with its PostinoDialogActions.
/// A dialog (`dialogTheme`, at most 480 wide) from `breakpoint-medium` (600), a bottom sheet (`bottomSheetTheme`)
/// below it. Esc and a tap outside answer [cancelValue], the cancel action's answer («Aspetta il Wi-Fi»);
/// to start the focus on an action give its PostinoButton `autofocus`. The route gives the focus back to what
/// had it before.
Future<T?> showPostinoDialog<T>(
  BuildContext context, {
  required String title,
  required Widget child,
  T? cancelValue,
}) async {
  final body = _DialogBody(title: title, child: child);
  // The nearest Navigator (the app has one), so a test can open it in a pane.
  final result = MediaQuery.sizeOf(context).width < PostinoSize.breakpointMedium
      ? await showModalBottomSheet<T>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          builder: (context) => Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
            child: body,
          ),
        )
      : await showDialog<T>(
          context: context,
          useRootNavigator: false,
          builder: (context) => Dialog(
            child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 480), child: body),
          ),
        );
  return result ?? cancelValue;
}

class const _DialogBody({required final String title, required final Widget child}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Semantics(
    namesRoute: true,
    scopesRoute: true,
    explicitChildNodes: true,
    label: title,
    child: Padding(
      padding: const EdgeInsets.all(PostinoSpacing.s6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: PostinoSpacing.s4,
        children: [
          Semantics(
            header: true,
            child: Text(title, style: PostinoText.sheetTitle.copyWith(color: context.pc.ink)),
          ),
          Flexible(child: SingleChildScrollView(child: child)),
        ],
      ),
    ),
  );
}
