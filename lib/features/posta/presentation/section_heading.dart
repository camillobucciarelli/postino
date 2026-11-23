import 'package:flutter/widgets.dart';

import '../../../design_system/design_system.dart';
import '../../../i18n/strings.g.dart';
import '../domain/inbox_sections.dart';
import 'list_items.dart';
import 'row_motion.dart';

/// The heading of a section of the posta in arrivo (#366), entering and leaving with the rows ([motion]):
/// name and count, and «Mostra tutti» ([onShowAll]) when the section has more than it shows.
Widget sectionHeading(
  BuildContext context,
  ListItem item, {
  required RowMotion<ListItem> motion,
  required void Function(InboxSection section)? onShowAll,
}) {
  final t = context.t.sezioni;
  final section = item.section!;
  final title = sectionTitle(context.t, section);
  final ik = itemKey(item);
  return PostinoSizeFade(
    key: ValueKey(ik),
    visibility: motion.of(ik),
    leaving: motion.leaving(ik),
    child: PostinoSectionHeader(
      title: title,
      count: item.count,
      semanticLabel: t.heading(n: item.count, title: title),
      actionLabel: t.showAll,
      actionSemanticLabel: t.showAllLabel(n: item.count, title: title),
      onAction: item.more ? () => onShowAll?.call(section) : null,
    ),
  );
}
