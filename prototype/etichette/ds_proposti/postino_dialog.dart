// PROTOTIPO (#106) — componente proposto per il design system (organismo).
import 'package:flutter/material.dart';
import 'package:postino/design_system/tokens/postino_theme.dart';
import 'package:postino/design_system/tokens/postino_tokens.dart';

/// A modal with [title] and [child] (the body and its PostinoDialogActions): a dialog (`dialogTheme`,
/// at most 480 wide) from `breakpoint-medium` (600), a bottom sheet (`bottomSheetTheme`) below it.
/// Esc and the scrim close it; the route returns the focus to what opened it.
Future<T?> showPostinoDialog<T>(BuildContext context, {required String title, required Widget child}) {
  final body = _DialogBody(title: title, child: child);
  if (MediaQuery.sizeOf(context).width < PostinoSize.breakpointMedium) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: body,
      ),
    );
  }
  return showDialog<T>(
    context: context,
    builder: (context) => Dialog(
      child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 480), child: body),
    ),
  );
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
          Flexible(child: child),
        ],
      ),
    ),
  );
}

/// The buttons at the bottom of a PostinoDialog, primary last; they wrap on a narrow window or large text.
class const PostinoDialogActions({super.key, required final List<Widget> children}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Wrap(alignment: WrapAlignment.end, spacing: PostinoSpacing.s2, runSpacing: PostinoSpacing.s2, children: children);
}
