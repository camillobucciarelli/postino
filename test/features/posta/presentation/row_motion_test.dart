// RowMotion (#282): which rows of the list enter and leave, and where the leaving ones stay drawn.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/domain/account.dart';
import 'package:postino/core/domain/inbox_repository.dart';
import 'package:postino/features/posta/presentation/row_motion.dart';

import '../../../support/fake_mail_provider.dart' show msg;

const _account = Account(id: 'a1', address: 'a@x.it', provider: ProviderKind.gmail, color: 0, position: 0);
const _enter = Duration(milliseconds: 200);
const _leave = Duration(milliseconds: 250);

InboxEntry _row(String id) => InboxEntry(
  message: msg(id, conversationId: 't$id'),
  account: _account,
  count: 1,
  unread: false,
);

final a = _row('a');
final b = _row('b');
final c = _row('c');
(String, String) _k(InboxEntry e) => (e.account.id, e.message.conversationId);

void main() {
  late int changed;
  late RowMotion<InboxEntry> motion;
  List<InboxEntry>? update(List<InboxEntry>? list, {bool reduced = false}) => motion.update(
    list == null ? null : [...list],
    enter: reduced ? Duration.zero : _enter,
    leave: reduced ? Duration.zero : _leave,
  );

  // Inside each test, so the controllers tick on its clock and are disposed before it ends.
  Future<void> start(WidgetTester tester) async {
    // A first frame: the tickers count from the test's own clock.
    await tester.pumpWidget(const SizedBox());
    changed = 0;
    motion = RowMotion<InboxEntry>(const TestVSync(), () => changed++, _k);
    addTearDown(motion.dispose);
  }

  testWidgets('nothing moves until rows were shown: loading, then the empty state the first sync fills', (
    tester,
  ) async {
    await start(tester);
    expect(update(null), isNull);
    expect(update([]), isEmpty);
    expect(update([a, b]), [a, b]);
    expect(motion.of(_k(a)), kAlwaysCompleteAnimation);
    expect(motion.of(_k(b)), kAlwaysCompleteAnimation);
  });

  testWidgets('a row that leaves stays drawn at its place, at the top too, until its animation ends', (tester) async {
    await start(tester);
    update([a, b, c]);
    expect(update([b, c]), [a, b, c]);
    expect(motion.leaving(_k(a)), isTrue);
    expect(update([a, c]), [a, b, c], reason: 'a turned round, b leaves under it');
    expect(update([c]), [a, b, c]);
    expect(motion.leaving(_k(b)), isTrue);
    await tester.pumpAndSettle();
    expect(changed, greaterThan(0));
    expect(update([c]), [c]);
    expect(motion.leaving(_k(a)), isFalse);
    expect(motion.of(_k(c)), kAlwaysCompleteAnimation);
  });

  testWidgets('a row that arrives enters from 0 to 1', (tester) async {
    await start(tester);
    update([a]);
    update([b, a]);
    final enter = motion.of(_k(b));
    expect(enter.value, 0);
    await tester.pump(_enter ~/ 2);
    await tester.pump(_enter ~/ 4);
    expect(enter.value, inExclusiveRange(0, 1));
    await tester.pump(_enter);
    expect(motion.of(_k(b)), kAlwaysCompleteAnimation);
  });

  testWidgets('a list that empties and fills again (Annulla on the last row) animates', (tester) async {
    await start(tester);
    update([a]);
    expect(update([]), [a]);
    await tester.pumpAndSettle();
    expect(update([]), isEmpty);
    update([a]);
    expect(motion.of(_k(a)).value, 0);
  });

  testWidgets('a row that leaves before it began to enter is dropped, without a rebuild asked during update', (
    tester,
  ) async {
    await start(tester);
    update([a]);
    update([b, a]);
    expect(update([a]), [a]);
    expect(changed, 0);
    expect(motion.leaving(_k(b)), isFalse);
    expect(motion.of(_k(b)), kAlwaysCompleteAnimation);
  });

  testWidgets('with reduced motion nothing moves', (tester) async {
    await start(tester);
    update([a, b]);
    expect(update([b, c], reduced: true), [b, c]);
    expect(motion.of(_k(c)), kAlwaysCompleteAnimation);
    expect(motion.leaving(_k(a)), isFalse);
  });

  testWidgets('the same list again changes nothing', (tester) async {
    await start(tester);
    update([a, b]);
    final list = [a];
    final shown = motion.update(list, enter: _enter, leave: _leave);
    expect(shown, [a, b]);
    expect(identical(motion.update(list, enter: _enter, leave: _leave), shown), isTrue);
  });

  testWidgets('fromEmpty: a list shown empty at first opens its first rows, after loading as at rest', (tester) async {
    await start(tester);
    motion = RowMotion<InboxEntry>(const TestVSync(), () => changed++, _k, fromEmpty: true);
    addTearDown(motion.dispose);
    expect(update(null), isNull);
    expect(update([a]), [a], reason: 'the first value after loading is just there');
    expect(motion.of(_k(a)), kAlwaysCompleteAnimation);

    final other = RowMotion<InboxEntry>(const TestVSync(), () {}, _k, fromEmpty: true);
    addTearDown(other.dispose);
    other.update([], enter: _enter, leave: _leave);
    expect(other.update([b], enter: _enter, leave: _leave), [b]);
    expect(other.of(_k(b)).value, 0, reason: 'empty at first, it opens from nothing');
  });
}
