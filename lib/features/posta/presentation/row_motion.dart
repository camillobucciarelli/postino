import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../../design_system/design_system.dart';

/// The rows of the list that enter or leave (#282): a row gone from the list stays drawn at its old place while it
/// fades and closes, a new one opens and fades in. Each moving row has its own controller, owned here and not by the
/// row, so a row scrolled away or rebuilt at another index still ends its animation; the others are at rest.
/// Nothing moves until the list has shown rows (loading, then the empty state the first sync fills), nor with reduced
/// motion (durations zero). Afterwards a list that empties and fills again (Annulla on the last row) animates.
/// A row is told apart by [_key] (the Conversazione for the inbox, the Conflitto in the list of the Conflitti, #283).
/// A row marked by [slideOut] (a swipe) is off the screen already when it leaves: its leave lasts twice as long,
/// the slide and then the closing (`PostinoSizeFade.slid`). The mark goes when the row is gone, comes back (Annulla),
/// or turns out to stay ([slideBack]).
/// [fromEmpty]: a list shown empty at first opens its first rows too (a column of banners, not an inbox that loads).
class RowMotion<T>(
  final TickerProvider _vsync,
  final VoidCallback _changed,
  final Object Function(T) _key, {
  final bool fromEmpty = false,
}) {
  final _moving = <Object, AnimationController>{};
  final _leaving = <Object>{};
  final _slid = <Object, PostinoSwipeSide>{};
  List<T>? _list;
  List<T>? _shown;
  late bool _hadRows = fromEmpty;

  /// Inside [update]: an animation that ends there at once (a row that leaves before it began to enter) must not ask
  /// for a rebuild during the build that called [update].
  bool _updating = false;

  /// The rows to draw for [list]: [list] itself, plus the rows still on their way out.
  List<T>? update(List<T>? list, {required Duration enter, required Duration leave}) {
    if (identical(list, _list)) return _shown;
    final before = _shown;
    _list = list;
    final rested = list == null || before == null || !_hadRows || enter == Duration.zero || leave == Duration.zero;
    _hadRows = _hadRows || (list?.isNotEmpty ?? false);
    if (rested) {
      _stop();
      return _shown = list;
    }
    _updating = true;
    try {
      return _shown = _diff(list, before, enter, leave);
    } finally {
      _updating = false;
    }
  }

  List<T> _diff(List<T> list, List<T> before, Duration enter, Duration leave) {
    final now = {for (final e in list) _key(e)};
    final was = {for (final e in before) _key(e)};
    for (final k in now) {
      // Back while leaving (Annulla): it turns round from where it is, fading in as any row.
      if (_leaving.remove(k)) {
        final c = _moving[k]!;
        if (_slid.remove(k) != null) {
          // Same height as now: on the slid curve the height is closed by the half of the way left below 0.5.
          c
            ..reverseDuration = leave
            ..value = math.min(c.value * 2, 1);
        }
        // At 1 already (back during the slide) the controller is gone.
        _moving[k]?.forward();
      } else if (!was.contains(k)) {
        _controller(k, 0, enter, leave).forward();
      }
    }
    for (final k in was) {
      if (!now.contains(k) && _leaving.add(k)) {
        final c = _moving[k] ?? _controller(k, 1, enter, leave);
        if (_slid.containsKey(k)) c.reverseDuration = leave * 2;
        c.reverse();
      }
    }
    final shown = [...list];
    for (var i = 0; i < before.length; i++) {
      if (!_leaving.contains(_key(before[i]))) continue;
      // Right under the row it was under (all of [before] up to here is in [shown]).
      final above = i == 0 ? -1 : shown.indexWhere((e) => _key(e) == _key(before[i - 1]));
      shown.insert(above + 1, before[i]);
    }
    return shown;
  }

  /// 1 at rest; between 0 and 1 while [key]'s row enters or leaves.
  Animation<double> of(Object key) => _moving[key] ?? kAlwaysCompleteAnimation;

  /// [key]'s row slides off the screen on [side] (a swipe): when it leaves, the list closes after the slide.
  void slideOut(Object key, PostinoSwipeSide side) => _slid[key] = side;

  /// The swipe's Azione left [key]'s row in the list: back in place, its next leave is the usual one. Nothing for a
  /// row already leaving.
  void slideBack(Object key) {
    if (!_leaving.contains(key)) _slid.remove(key);
  }

  /// The side [key]'s row is off the screen on after a swipe (see [slideOut]), until it is gone or back in place.
  PostinoSwipeSide? slid(Object key) => _slid[key];

  /// [key]'s row is on its way out.
  bool leaving(Object key) => _leaving.contains(key);

  AnimationController _controller(Object key, double from, Duration enter, Duration leave) =>
      _moving[key] = AnimationController(vsync: _vsync, value: from, duration: enter, reverseDuration: leave)
        ..addStatusListener((s) {
          if (s.isAnimating) return;
          _moving.remove(key)?.dispose();
          _slid.remove(key);
          if (_leaving.remove(key)) _shown = [...?_shown]..removeWhere((e) => _key(e) == key);
          if (!_updating) _changed();
        });

  void _stop() {
    for (final c in _moving.values) {
      c.dispose();
    }
    _moving.clear();
    _leaving.clear();
    _slid.clear();
  }

  void dispose() => _stop();
}
