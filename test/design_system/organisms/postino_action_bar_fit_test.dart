// The twin of postino_action_bar_fit.dart: what a PostinoActionBar keeps in its width (#369).
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/design_system/design_system.dart';
import 'package:postino/design_system/organisms/postino_action_bar_fit.dart';

void _noop() {}

PostinoBarAction _a(String label, {int? overflow, bool primary = false}) =>
    PostinoBarAction(icon: PostinoIcons.star, label: label, onPressed: _noop, overflow: overflow, primary: primary);

final _archive = _a('Archivia');
final _star = _a('Stella', overflow: 1);
final _labels = _a('Etichette', overflow: 0);
final _reply = _a('Rispondi', primary: true);

/// Archivia | Stella, Etichette | Rispondi: 4 tap targets.
final _groups = [
  [_archive],
  [_star, _labels],
  [_reply],
];

List<String> _labelsOf(Iterable<PostinoBarAction> a) => [for (final x in a) x.label];

void main() {
  test('with room all stay, the dividers too', () {
    final fit = fitActionBar(_groups, 4 * 48 + 2 * 17, divider: 17);
    expect(fit.shown.map(_labelsOf), [
      ['Archivia'],
      ['Stella', 'Etichette'],
      ['Rispondi'],
    ]);
    expect(fit.more, isEmpty);
    expect(fit.dividers, isTrue);
  });

  test('one short: the lowest overflow leaves, and the next too, as the «more» button takes a slot', () {
    final fit = fitActionBar(_groups, 4 * 48 + 2 * 17 - 1, divider: 17);
    expect(_labelsOf(fit.more), ['Stella', 'Etichette'], reason: 'in the bar order');
    expect(fit.shown[1], isEmpty);
    expect(fit.menuGroup, 1, reason: 'the menu closes the group of the first to leave');
    expect(fit.dividers, isTrue);
  });

  test('the ones without an overflow stay; the dividers give way when even that does not fit', () {
    final fit = fitActionBar(_groups, 3 * 48, divider: 17);
    expect(_labelsOf(fit.shown.expand((g) => g)), ['Archivia', 'Rispondi']);
    expect(fit.dividers, isFalse);
  });

  test('the primary takes its label only when everything fits with it; it gives way before any action', () {
    expect(fitActionBar(_groups, 3 * 48 + 120, extendedPrimary: 120).extended, isTrue);
    final short = fitActionBar(_groups, 3 * 48 + 119, extendedPrimary: 120);
    expect(short.extended, isFalse);
    expect(short.more, isEmpty);
    expect(fitActionBar(_groups, 1000).extended, isFalse, reason: 'no width given: never');
  });
}
