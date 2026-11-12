// The buttons of a notification on Windows, Linux and the Apple platforms (#211).
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/data/notification_buttons.dart';
import 'package:postino/core/data/notification_payload.dart';
import 'package:postino/core/domain/notification_action.dart';

const _t = (accountId: 'a1', conversationId: 't-a');
String _label(NotificationAction a) => 'label-${a.name}';

void main() {
  test('Windows: each button hands back its Azione on the Conversazione', () {
    final buttons = windowsButtons(_t, const [NotificationAction.archive, NotificationAction.delete], _label);

    expect([for (final b in buttons) b.content], ['label-archive', 'label-delete']);
    expect([for (final b in buttons) decodeAction(b.arguments, b.arguments)], [
      (conversation: _t, action: NotificationAction.archive),
      (conversation: _t, action: NotificationAction.delete),
    ]);
  });

  test('Linux: the key of a button is its Azione', () {
    final buttons = linuxButtons(const [NotificationAction.star], _label);
    expect([for (final b in buttons) (b.key, b.label)], [('star', 'label-star')]);
  });

  test('Apple: one category per choice with buttons, Elimina destructive', () {
    final categories = {for (final c in darwinCategories(_label)) c.identifier: c};

    // 4 with one button, 12 with two different ones.
    expect(categories, hasLength(16));
    final defaults = categories[darwinCategoryOf(buttonsOf(notificationActionsDefault))]!;
    expect([for (final a in defaults.actions) (a.identifier, a.title)], [
      ('archive', 'label-archive'),
      ('markRead', 'label-markRead'),
    ]);
    expect(categories[darwinCategoryOf(const [NotificationAction.delete])]!.actions.single.options, isNotEmpty);
    expect(categories[darwinCategoryOf(const [NotificationAction.star])]!.actions.single.options, isEmpty);
  });
}
