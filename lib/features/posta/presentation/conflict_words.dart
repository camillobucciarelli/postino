import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:get_it/get_it.dart';

import '../../../core/domain/conflict.dart';
import '../../../core/domain/inbox_repository.dart';
import '../../../core/domain/mail_action.dart';
import '../../../i18n/strings.g.dart';

/// A value of an attribute in words: «archiviato», «da leggere», «con l'etichetta Lavoro».
String conflictValue(Translations$conflitti$values$it v, String attribute, Object value, String labelName) =>
    switch ((attribute, value)) {
      (readAttribute, true) => v.read,
      (readAttribute, _) => v.unread,
      (starredAttribute, true) => v.starred,
      (starredAttribute, _) => v.unstarred,
      (placementAttribute, Placement.archive) => v.archive,
      (placementAttribute, Placement.trash) => v.trash,
      (placementAttribute, _) => v.inbox,
      (_, true) => v.labeled(name: labelName),
      _ => v.unlabeled(name: labelName),
    };

/// The two versions of a [conflict] in words, «La tua: archiviato» and «Provider: in posta in arrivo», for [builder].
/// An Etichetta is named from the Account's, so it follows renames.
class const ConflictWords({
  super.key,
  required final Conflict conflict,
  required final Widget Function(BuildContext context, String mine, String provider) builder,
}) extends StatefulWidget {
  @override
  State<ConflictWords> createState() => _ConflictWordsState();
}

class _ConflictWordsState() extends State<ConflictWords> {
  StreamSubscription<Object?>? _sub;
  late String _label = labelIdOf(widget.conflict.local.attribute) ?? '';

  @override
  void initState() {
    super.initState();
    final id = labelIdOf(widget.conflict.local.attribute);
    if (id == null) return;
    _sub = GetIt.I<InboxRepository>().watchLabels(widget.conflict.accountId).listen((labels) {
      final name = labels.where((l) => l.id == id).firstOrNull?.name;
      if (name != null && name != _label && mounted) setState(() => _label = name);
    });
  }

  @override
  void dispose() {
    unawaited(_sub?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t.conflitti;
    final c = widget.conflict;
    final attribute = c.local.attribute;
    return widget.builder(
      context,
      t.mine(value: conflictValue(t.values, attribute, c.local.wanted, _label)),
      t.provider(value: conflictValue(t.values, attribute, c.provider, _label)),
    );
  }
}
