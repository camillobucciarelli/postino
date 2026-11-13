// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import '../atoms/postino_account_mark.dart';
import '../tokens/postino_theme.dart';
import '../tokens/postino_tokens.dart';
import 'postino_message_detail.dart';

/// The details of an expanded message, under its avatar's column: label in `ink-subtle`, value in `ink`.
class const PostinoMessageDetailsPanel(
  /// One table row each.
  final List<PostinoMessageDetail> rows, {
  super.key,
}) extends StatelessWidget {
  /// Crea il pannello con le righe `rows`.
  this;

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    const style = PostinoText.caption;
    return Padding(
      padding: const EdgeInsets.only(top: PostinoSpacing.s3, left: PostinoSize.avatarMd + PostinoSpacing.s3),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: c.surfaceGround,
          borderRadius: const BorderRadius.all(Radius.circular(PostinoRadius.sm)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(PostinoSpacing.s3),
          child: Table(
            columnWidths: const {0: IntrinsicColumnWidth(), 1: FlexColumnWidth()},
            children: [
              for (final r in rows)
                TableRow(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: PostinoSpacing.s3, bottom: PostinoSpacing.s0_5),
                      child: Text(r.label, style: style.copyWith(color: c.inkSubtle)),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: PostinoSpacing.s0_5),
                      child: Text.rich(
                        TextSpan(
                          children: [
                            if (r.account case final a?) ...[
                              WidgetSpan(
                                alignment: PlaceholderAlignment.middle,
                                child: PostinoAccountMark(
                                  color: a.color,
                                  initial: a.initial,
                                  size: PostinoSize.accountBadge,
                                ),
                              ),
                              const TextSpan(text: ' '),
                            ],
                            TextSpan(text: r.value),
                          ],
                        ),
                        style: style.copyWith(color: c.ink),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
