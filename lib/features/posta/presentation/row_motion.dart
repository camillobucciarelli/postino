import 'package:flutter/widgets.dart';

import '../../../core/domain/inbox_repository.dart';

/// The rows of the list that enter or leave (#282): a row gone from the list stays drawn at its old place while it
/// fades and closes, a new one opens and fades in. Each moving row has its own controller, owned here and not by the
/// row, so a row scrolled away or rebuilt at another index still ends its animation; the others are at rest.
/// Nothing moves on the first rows (after loading or the empty state), nor with reduced motion (durations zero).
class RowMotion(final TickerProvider _vsync, final VoidCallback _changed) {
  final _moving = <(String, String), AnimationController>{};
  final _leaving = <(String, String)>{};
  List<InboxEntry>? _list;
  List<InboxEntry>? _shown;

  /// The rows to draw for [list]: [list] itself, plus the rows still on their way out.
  List<InboxEntry>? update(List<InboxEntry>? list, {required Duration enter, required Duration leave}) {
    if (identical(list, _list)) return _shown;
    final before = _shown;
    _list = list;
    // From nothing (loading, or the empty state the first sync fills) the rows just appear.
    if (list == null || before == null || before.isEmpty || enter == Duration.zero || leave == Duration.zero) {
      _stop();
      return _shown = list;
    }
    final now = {for (final e in list) _key(e)};
    final was = {for (final e in before) _key(e)};
    for (final k in now) {
      // Back while leaving (Annulla): it turns round from where it is.
      if (_leaving.remove(k)) {
        _moving[k]!.forward();
      } else if (!was.contains(k)) {
        _controller(k, 0, enter, leave).forward();
      }
    }
    for (final k in was) {
      if (!now.contains(k) && _leaving.add(k)) {
        (_moving[k] ?? _controller(k, 1, enter, leave)).reverse();
      }
    }
    final shown = [...list];
    for (var i = 0; i < before.length; i++) {
      if (!_leaving.contains(_key(before[i]))) continue;
      // Right under the row it was under (all of [before] up to here is in [shown]).
      final above = i == 0 ? -1 : shown.indexWhere((e) => _key(e) == _key(before[i - 1]));
      shown.insert(above + 1, before[i]);
    }
    return _shown = shown;
  }

  /// 1 at rest; between 0 and 1 while [key]'s row enters or leaves.
  Animation<double> of((String, String) key) => _moving[key] ?? kAlwaysCompleteAnimation;

  /// [key]'s row is on its way out.
  bool leaving((String, String) key) => _leaving.contains(key);

  AnimationController _controller((String, String) key, double from, Duration enter, Duration leave) =>
      _moving[key] = AnimationController(vsync: _vsync, value: from, duration: enter, reverseDuration: leave)
        ..addStatusListener((s) {
          if (s.isAnimating) return;
          _moving.remove(key)?.dispose();
          if (_leaving.remove(key)) _shown = [...?_shown]..removeWhere((e) => _key(e) == key);
          _changed();
        });

  void _stop() {
    for (final c in _moving.values) {
      c.dispose();
    }
    _moving.clear();
    _leaving.clear();
  }

  void dispose() => _stop();
}

(String, String) _key(InboxEntry e) => (e.account.id, e.message.conversationId);
