// The adapter on Android (#210), over a fake of the plugin's method channel: the group of each Account, the summary
// that replaces only its Account's notifications, and the group that goes with its last child.
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/core/data/local_notifications.dart';
import 'package:postino/core/data/notification_action_relay.dart';
import 'package:postino/core/data/notification_payload.dart';
import 'package:postino/core/domain/mail_notification.dart';
import 'package:postino/core/domain/new_mail_summary.dart';
import 'package:postino/core/domain/notification_action.dart';
import 'package:postino/core/domain/notification_target.dart';

const _channel = MethodChannel('dexterous.com/flutter/local_notifications');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// What the OS shows: id → groupKey.
  late Map<int, String?> shown;
  late List<int> cancels;
  late LocalNotifications notifications;

  /// The buttons of each notification shown: id → action id → title.
  late Map<int, Map<String, String>> buttons;
  late List<NotificationActionTap> actions;
  late List<NotificationTarget> taps;

  /// What the OS says launched the app.
  Map<String, Object?>? launch;

  /// Runs inside the plugin's `initialize`: what Android delivers there on a cold start.
  Future<void> Function()? duringInitialize;

  MailNotification mail(String accountId, String conversationId, {List<NotificationAction> actions = const []}) =>
      MailNotification(
        conversation: (accountId: accountId, conversationId: conversationId),
        accountAddress: '$accountId@example.com',
        sender: 'Ada',
        subject: 'Oggetto',
        preview: 'Anteprima',
        actions: actions,
      );

  setUp(() async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    shown = {};
    buttons = {};
    cancels = [];
    launch = null;
    duringInitialize = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_channel, (call) async {
      final args = call.arguments;
      switch (call.method) {
        case 'initialize':
          await duringInitialize?.call();
          return true;
        case 'getNotificationAppLaunchDetails':
          return launch;
        case 'show':
          final map = args as Map;
          final specifics = map['platformSpecifics'] as Map?;
          shown[map['id'] as int] = specifics?['groupKey'] as String?;
          buttons[map['id'] as int] = {
            for (final a in (specifics?['actions'] as List?) ?? const [])
              (a as Map)['id'] as String: a['title'] as String,
          };
        case 'cancel':
          final id = (args as Map)['id'] as int;
          cancels.add(id);
          shown.remove(id);
        case 'getActiveNotifications':
          return [
            for (final MapEntry(:key, :value) in shown.entries) {'id': key, 'groupKey': value},
          ];
      }
      return null;
    });
    actions = [];
    taps = [];
    notifications = LocalNotifications();
    notifications.taps.listen(taps.add);
    await notifications.start(
      channelName: 'Posta nuova',
      openLabel: 'Apri',
      newMessages: (n) => '$n nuovi messaggi',
      actionLabel: (a) => 'label-${a.name}',
      onAction: actions.add,
    );
  });

  /// The OS reporting a tap on the notification of [conversationId], on its button [actionId] when given.
  Future<void> respond(String conversationId, {String? actionId}) async {
    final call = MethodCall('didReceiveNotificationResponse', {
      'notificationId': 1,
      'actionId': actionId,
      'payload': encodePayload(ConversationTarget((accountId: 'a1', conversationId: conversationId))),
      'notificationResponseType': actionId == null ? 0 : 1,
    });
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.handlePlatformMessage(
      _channel.name,
      const StandardMethodCodec().encodeMethodCall(call),
      (_) {},
    );
    await pumpEventQueue();
  }

  test('a notification has the buttons of its Azioni, titled and in order (#211)', () async {
    await notifications.show(mail('a1', 't-a', actions: const [NotificationAction.delete, NotificationAction.star]));

    expect(buttons[notificationId((accountId: 'a1', conversationId: 't-a'))], {
      'delete': 'label-delete',
      'star': 'label-star',
    });
  });

  test('a button runs its Azione on the Conversazione; a tap on the notification opens it', () async {
    await respond('t-a', actionId: 'archive');
    await respond('t-b');

    expect(actions, [(conversation: (accountId: 'a1', conversationId: 't-a'), action: NotificationAction.archive)]);
    expect(taps, [const ConversationTarget((accountId: 'a1', conversationId: 't-b'))]);
  });

  test(
    'a tap with nobody listening yet waits for the first listener (#214: the engine kept without the app)',
    () async {
      final headless = LocalNotifications();
      await headless.start(
        channelName: 'Posta nuova',
        openLabel: 'Apri',
        newMessages: (n) => '$n nuovi messaggi',
        actionLabel: (a) => a.name,
        onAction: actions.add,
      );
      await respond('t-late');
      final late = <NotificationTarget>[];
      headless.taps.listen(late.add);
      await pumpEventQueue();
      expect(late, [const ConversationTarget((accountId: 'a1', conversationId: 't-late'))]);
    },
  );

  test(
    'the tap that launched the app, delivered inside initialize, is the launch only: nothing for a listener',
    () async {
      final cold = LocalNotifications();
      duringInitialize = () => respond('t-launch');
      launch = {
        'notificationLaunchedApp': true,
        'notificationResponse': {
          'notificationId': 1,
          'payload': encodePayload(const ConversationTarget((accountId: 'a1', conversationId: 't-launch'))),
          'notificationResponseType': 0,
        },
      };
      final target = await cold.start(
        channelName: 'Posta nuova',
        openLabel: 'Apri',
        newMessages: (n) => '$n nuovi messaggi',
        actionLabel: (a) => a.name,
        onAction: actions.add,
      );
      expect(target, const ConversationTarget((accountId: 'a1', conversationId: 't-launch')));
      final late = <NotificationTarget>[];
      cold.taps.listen(late.add);
      await pumpEventQueue();
      expect(late, isEmpty, reason: 'opened once, by the launch');
    },
  );

  test("a background task's start (#212) leaves the relayed buttons to the app's isolate", () async {
    await LocalNotifications().start(
      channelName: 'Posta nuova',
      openLabel: 'Apri',
      newMessages: (n) => '$n',
      actionLabel: (a) => a.name,
      onAction: null,
    );
    const tap = (conversation: (accountId: 'a1', conversationId: 't-a'), action: NotificationAction.star);

    expect(await relayToApp(tap), isTrue);
    await pumpEventQueue();
    expect(actions, [tap], reason: 'the app started in setUp still takes it');
  });

  test('a button that launched the app runs its Azione, and the app opens on nothing in particular', () async {
    final payload = encodePayload(const ConversationTarget((accountId: 'a1', conversationId: 't-a')));
    launch = {
      'notificationLaunchedApp': true,
      'notificationResponse': {
        'notificationId': 1,
        'actionId': 'delete',
        'payload': payload,
        'notificationResponseType': 1,
      },
    };
    final launched = <NotificationActionTap>[];
    final target = await LocalNotifications().start(
      channelName: 'Posta nuova',
      openLabel: 'Apri',
      newMessages: (n) => '$n',
      actionLabel: (a) => a.name,
      onAction: launched.add,
    );

    expect(target, isNull);
    expect(launched, [(conversation: (accountId: 'a1', conversationId: 't-a'), action: NotificationAction.delete)]);

    launch = {
      ...launch!,
      'notificationResponse': {...launch!['notificationResponse']! as Map, 'actionId': null},
    };
    expect(
      await LocalNotifications().start(
        channelName: 'Posta nuova',
        openLabel: 'Apri',
        newMessages: (n) => '$n',
        actionLabel: (a) => a.name,
        onAction: launched.add,
      ),
      const ConversationTarget((accountId: 'a1', conversationId: 't-a')),
      reason: 'a tap on the notification itself opens its Conversazione',
    );
    expect(launched, hasLength(1));
  });

  test('iOS: the notification names a category registered at start with its buttons, for any choice', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    IOSFlutterLocalNotificationsPlugin.registerWith();
    final categories = <String, List<String>>{};
    String? category;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_channel, (call) async {
      final args = call.arguments as Map?;
      switch (call.method) {
        case 'initialize':
          for (final c in args!['notificationCategories'] as List) {
            categories[(c as Map)['identifier'] as String] = [
              for (final a in c['actions'] as List) (a as Map)['identifier'] as String,
            ];
          }
          return true;
        case 'show':
          category = (args!['platformSpecifics'] as Map)['categoryIdentifier'] as String?;
      }
      return null;
    });
    final ios = LocalNotifications();
    await ios.start(
      channelName: 'Posta nuova',
      openLabel: 'Apri',
      newMessages: (n) => '$n',
      actionLabel: (a) => a.name,
      onAction: (_) {},
    );

    await ios.show(mail('a1', 't-a', actions: const [NotificationAction.star, NotificationAction.archive]));
    expect(categories[category], ['star', 'archive']);
    await ios.show(mail('a1', 't-a', actions: const [NotificationAction.delete]));
    expect(categories[category], ['delete']);
    await ios.show(mail('a1', 't-a'));
    expect(category, isNull);
  });

  test('a button that dismissed its notification itself still takes the empty group away', () async {
    await notifications.show(mail('a1', 't-a'));
    shown.remove(notificationId((accountId: 'a1', conversationId: 't-a')));

    await notifications.cancel(const [ConversationTarget((accountId: 'a1', conversationId: 't-a'))]);
    expect(shown, isEmpty);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_channel, null);
    debugDefaultTargetPlatformOverride = null;
  });

  test('each notification joins the group of its Account, with the group notification', () async {
    await notifications.show(mail('a1', 't-a'));
    await notifications.show(mail('a2', 't-b'));

    expect(shown, {
      notificationId((accountId: 'a1', conversationId: 't-a')): 'a1',
      groupId('a1'): 'a1',
      notificationId((accountId: 'a2', conversationId: 't-b')): 'a2',
      groupId('a2'): 'a2',
    });
  });

  test("the summary replaces its Account's notifications, not another Account's", () async {
    await notifications.show(mail('a1', 't-a'));
    await notifications.show(mail('a1', 't-b'));
    await notifications.show(mail('a2', 't-c'));
    await notifications.showSummary(const NewMailSummary(accountId: 'a1', accountAddress: 'a1@example.com', count: 11));

    expect(shown.keys, {
      summaryId('a1'),
      groupId('a1'),
      notificationId((accountId: 'a2', conversationId: 't-c')),
      groupId('a2'),
    });
  });

  test('cancelling the last child drops its group; one not shown is not cancelled', () async {
    await notifications.show(mail('a1', 't-a'));
    await notifications.show(mail('a1', 't-b'));

    await notifications.cancel(const [
      ConversationTarget((accountId: 'a1', conversationId: 't-a')),
      ConversationTarget((accountId: 'a1', conversationId: 'never-shown')),
    ]);
    expect(shown.keys, {notificationId((accountId: 'a1', conversationId: 't-b')), groupId('a1')});
    expect(cancels, [notificationId((accountId: 'a1', conversationId: 't-a'))]);

    await notifications.cancel(const [ConversationTarget((accountId: 'a1', conversationId: 't-b'))]);
    expect(shown, isEmpty);
  });
}
