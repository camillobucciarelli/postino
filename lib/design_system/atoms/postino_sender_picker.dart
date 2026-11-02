import 'package:flutter/material.dart';

import '../tokens/postino_icons.dart';
import '../tokens/postino_theme.dart';
import '../tokens/postino_tokens.dart';
import 'postino_account_mark.dart';
import 'postino_focus_ring.dart';
import 'postino_icon.dart';

/// One Account a message can leave from.
typedef PostinoSenderOption = ({
  Object id,
  PostinoAccountRef mark,
  String address,
});

/// The «Da» row of the composer: the sender's mark and address, a menu with the other Accounts on tap;
/// not [enabled], it only shows the sender.
class PostinoSenderPicker extends StatelessWidget {
  const PostinoSenderPicker({
    super.key,
    required this.options,
    required this.selectedId,
    required this.onSelected,
    required this.label,
    this.enabled = true,
  });

  final List<PostinoSenderOption> options;
  final Object selectedId;
  final ValueChanged<Object> onSelected;
  final String label;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    final selected = options.firstWhere((o) => o.id == selectedId);
    return MenuAnchor(
      menuChildren: [
        for (final o in options)
          MenuItemButton(
            onPressed: () => onSelected(o.id),
            leadingIcon: PostinoAccountMark(
              color: o.mark.color,
              initial: o.mark.initial,
            ),
            child: Text(o.address),
          ),
      ],
      builder: (context, menu, _) => MergeSemantics(
        child: Semantics(
          button: true,
          enabled: enabled,
          label: '$label: ${selected.address}',
          child: InkWell(
            onTap: enabled
                ? () => menu.isOpen ? menu.close() : menu.open()
                : null,
            // A control, not content: its address is out of any selection and of the merged label.
            child: ExcludeSemantics(
              child: SelectionContainer.disabled(
                child: PostinoFocusRing(
                  inset: true,
                  child: Container(
                    constraints: const BoxConstraints(
                      minHeight: PostinoSize.touchTargetAndroid,
                    ),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: c.composerFieldDivider),
                      ),
                    ),
                    child: Row(
                      spacing: PostinoSpacing.s3,
                      children: [
                        Text(
                          label,
                          style: PostinoText.label.copyWith(color: c.inkMuted),
                        ),
                        PostinoAccountMark(
                          color: selected.mark.color,
                          initial: selected.mark.initial,
                        ),
                        Expanded(
                          child: Text(
                            selected.address,
                            style: PostinoText.body.copyWith(color: c.ink),
                          ),
                        ),
                        PostinoIcon(
                          PostinoIcons.chevronDown,
                          color: c.inkMuted,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
