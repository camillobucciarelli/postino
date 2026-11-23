// ignore: deprecated_member_use
import 'package:flutter/material.dart' show kMinInteractiveDimension;

import 'postino_bar_action.dart';

/// What a PostinoActionBar shows in its width: per group the actions on the bar, those in the «more» menu (in the
/// bar's order), the group the menu closes, whether the primary action shows its label and the dividers show.
typedef PostinoBarFit = ({
  List<List<PostinoBarAction>> shown,
  List<PostinoBarAction> more,
  int menuGroup,
  bool extended,
  bool dividers,
});

/// Fits [groups] in [width]: every button one tap target, [divider] between two groups, the primary action
/// [extendedPrimary] wide with its label (0: never). The label goes first, then the actions with an `overflow`, the
/// lowest first, behind one «more» button; those without one stay, the dividers giving way last.
// ponytail: every action counted as one tap target (icon buttons); a wider one beside the primary needs measuring.
PostinoBarFit fitActionBar(
  List<List<PostinoBarAction>> groups,
  double width, {
  double divider = 0,
  double extendedPrimary = 0,
}) {
  double cost(Set<PostinoBarAction> out, {required bool extended}) {
    var total = out.isEmpty ? 0.0 : kMinInteractiveDimension;
    var filled = 0;
    for (final (i, g) in groups.indexed) {
      final here = g.where((a) => !out.contains(a));
      for (final a in here) {
        total += a.primary && extended ? extendedPrimary : kMinInteractiveDimension;
      }
      if (here.isNotEmpty || (out.isNotEmpty && i == _menuGroup(groups))) filled++;
    }
    return total + divider * (filled - 1).clamp(0, groups.length);
  }

  final extended = extendedPrimary > 0 && cost(const {}, extended: true) <= width;
  final leaving = [
    for (final g in groups)
      for (final a in g)
        if (a.overflow != null) a,
  ]..sort((a, b) => a.overflow!.compareTo(b.overflow!));
  final out = <PostinoBarAction>{};
  for (final a in leaving) {
    if (cost(out, extended: extended) <= width) break;
    out.add(a);
  }
  final dividers = divider == 0 || cost(out, extended: extended) <= width;
  return (
    shown: [
      for (final g in groups)
        [
          for (final a in g)
            if (!out.contains(a)) a,
        ],
    ],
    more: [
      for (final g in groups)
        for (final a in g)
          if (out.contains(a)) a,
    ],
    menuGroup: _menuGroup(groups),
    extended: extended,
    dividers: dividers,
  );
}

/// The group of the action that leaves first: the «more» menu closes it.
int _menuGroup(List<List<PostinoBarAction>> groups) {
  var best = (group: 0, rank: 1 << 30);
  for (final (i, g) in groups.indexed) {
    for (final a in g) {
      if (a.overflow case final r? when r < best.rank) best = (group: i, rank: r);
    }
  }
  return best.group;
}
