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
import 'package:postino/core/domain/notification_action.dart';
import 'package:postino/core/domain/notification_target.dart';

const _channel = MethodChannel('dexterous.com/flutter/local_notifications');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// What the OS shows: id → groupKey.
  late Map<int, String?> shown;

  /// The title and body each notification was last shown with.
  late Map<int, ({String? title, String? body})> texts;

  /// Shown, yet not listed yet: Android posts asynchronously.
  late Set<int> lagging;
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

  MailNotification mail(
    String accountId,
    String messageId, {
    String conversationId = 't',
    List<NotificationAction> actions = const [],
  }) => MailNotification(
    conversation: (accountId: accountId, conversationId: conversationId),
    messageId: messageId,
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
    texts = {};
    lagging = {};
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
          final id = map['id'] as int;
          shown[id] = specifics?['groupKey'] as String?;
          texts[id] = (title: map['title'] as String?, body: map['body'] as String?);
          buttons[id] = {
            for (final a in (specifics?['actions'] as List?) ?? const [])
              (a as Map)['id'] as String: a['title'] as String,
          };
        case 'cancel':
          final id = (args as Map)['id'] as int;
          cancels.add(id);
          shown.remove(id);
        case 'getActiveNotifications':
          return [
            for (final MapEntry(:key, :value) in shown.entries)
              if (!lagging.contains(key)) {'id': key, 'groupKey': value, 'body': texts[key]?.body},
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

  /// The OS reporting a tap on the notification of [conversationId], on its button [actionId] when given; [payload]
  /// in place of the notification's own.
  Future<void> respond(String conversationId, {String? actionId, String? payload}) async {
    final call = MethodCall('didReceiveNotificationResponse', {
      'notificationId': 1,
      'actionId': actionId,
      'payload': payload ?? encodePayload(ConversationTarget((accountId: 'a1', conversationId: conversationId))),
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
    await notifications.show(mail('a1', 'm1', actions: const [NotificationAction.delete, NotificationAction.star]));
    await notifications.show(mail('a1', 'm2', actions: const [NotificationAction.delete, NotificationAction.star]));

    expect(buttons[groupId('a1')], isEmpty, reason: 'the summary has none');
    expect(buttons[notificationId('a1', 'm1')], buttons[notificationId('a1', 'm2')]);
    expect(buttons[notificationId('a1', 'm1')], {'delete': 'label-delete', 'star': 'label-star'});
  });

  test('macOS: a button runs its Azione on the Conversazione; a tap on the notification opens it', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    MacOSFlutterLocalNotificationsPlugin.registerWith();
    final macos = LocalNotifications();
    final macTaps = <NotificationTarget>[];
    macos.taps.listen(macTaps.add);
    await macos.start(
      channelName: 'Posta nuova',
      openLabel: 'Apri',
      newMessages: (n) => '$n',
      actionLabel: (a) => a.name,
      onAction: actions.add,
    );

    await respond('t-a', actionId: 'archive');
    await respond('t-c', payload: encodeAction(_star('t-c')));
    await respond('t-b');

    expect(actions, [
      (conversation: (accountId: 'a1', conversationId: 't-a'), action: NotificationAction.archive),
      _star('t-c'),
    ]);
    expect(macTaps, [const ConversationTarget((accountId: 'a1', conversationId: 't-b'))]);
  });

  test("Android: the app's isolate never runs an Azione, its buttons run in the background engine", () async {
    await respond('t-a', actionId: 'archive');
    await respond('t-b', payload: encodeAction(_star('t-b')));

    expect(actions, isEmpty, reason: "any app can send these to the exported Activity");
    expect(taps, [const ConversationTarget((accountId: 'a1', conversationId: 't-a'))], reason: 'it opens, like a tap');
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

  test('macOS: a button that launched the app runs its Azione, and the app opens on nothing in particular', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    MacOSFlutterLocalNotificationsPlugin.registerWith();
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

  test('Android: a launch with a button runs no Azione, it opens its Conversazione', () async {
    Future<NotificationTarget?> launchWith(String? actionId, String payload) {
      launch = {
        'notificationLaunchedApp': true,
        'notificationResponse': {
          'notificationId': 1,
          'actionId': actionId,
          'payload': payload,
          'notificationResponseType': 1,
        },
      };
      return LocalNotifications().start(
        channelName: 'Posta nuova',
        openLabel: 'Apri',
        newMessages: (n) => '$n',
        actionLabel: (a) => a.name,
        onAction: actions.add,
      );
    }

    expect(
      await launchWith('delete', encodePayload(const ConversationTarget((accountId: 'a1', conversationId: 't-a')))),
      const ConversationTarget((accountId: 'a1', conversationId: 't-a')),
    );
    expect(await launchWith(null, encodeAction(_star('t-b'))), isNull);
    expect(actions, isEmpty);
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

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_channel, null);
    debugDefaultTargetPlatformOverride = null;
  });

  String? summaryTitle(String accountId) =>
      shown.containsKey(groupId(accountId)) ? texts[groupId(accountId)]?.title : null;

  test('one notification per message in the group of its Account; the summary from the second on (#238)', () async {
    await notifications.show(mail('a1', 'm1'));
    expect(shown, {notificationId('a1', 'm1'): 'a1'}, reason: 'one message alone: no summary');

    await notifications.show(mail('a1', 'm2'));
    await notifications.show(mail('a1', 'm3'));
    await notifications.show(mail('a2', 'b1'));

    expect(shown, {
      notificationId('a1', 'm1'): 'a1',
      notificationId('a1', 'm2'): 'a1',
      notificationId('a1', 'm3'): 'a1',
      groupId('a1'): 'a1',
      notificationId('a2', 'b1'): 'a2',
    });
    expect(summaryTitle('a1'), '3 nuovi messaggi');
    expect(texts[groupId('a1')]?.body, 'a1@example.com');
  });

  test('a message not listed yet (Android posts asynchronously) still counts', () async {
    lagging.add(notificationId('a1', 'm1'));
    await notifications.show(mail('a1', 'm1'));
    await notifications.show(mail('a1', 'm2'));

    expect(summaryTitle('a1'), '2 nuovi messaggi');
  });

  test('a message cancelled: its notification goes and the summary counts down; the last takes it away', () async {
    for (final m in ['m1', 'm2', 'm3']) {
      await notifications.show(mail('a1', m));
    }
    await notifications.show(mail('a2', 'b1'));
    await notifications.show(mail('a2', 'b2'));

    await notifications.cancel('a1', ['m1', 'never-shown']);
    expect(cancels, [notificationId('a1', 'm1')], reason: 'one not shown is not cancelled');
    expect(summaryTitle('a1'), '2 nuovi messaggi');
    expect(texts[groupId('a1')]?.body, 'a1@example.com', reason: 'the address it showed');

    await notifications.cancel('a1', ['m2']);
    expect(summaryTitle('a1'), '1 nuovi messaggi', reason: 'cancelling a summary would take its child with it');

    await notifications.cancel('a1', ['m3']);
    expect(shown.keys, {notificationId('a2', 'b1'), notificationId('a2', 'b2'), groupId('a2')});
    expect(summaryTitle('a2'), '2 nuovi messaggi', reason: "another Account's group is left alone");
  });

  test('a button that dismissed its notifications itself still takes the empty summary away', () async {
    await notifications.show(mail('a1', 'm1'));
    await notifications.show(mail('a1', 'm2'));
    shown
      ..remove(notificationId('a1', 'm1'))
      ..remove(notificationId('a1', 'm2'));

    await notifications.cancel('a1', ['m1', 'm2']);
    expect(shown, isEmpty);
  });
}

NotificationActionTap _star(String conversationId) =>
    (conversation: (accountId: 'a1', conversationId: conversationId), action: NotificationAction.star);
