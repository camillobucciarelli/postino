import 'dart:async';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:injectable/injectable.dart';

import '../domain/mail_notification.dart';
import '../domain/notification_action.dart';
import '../domain/notification_target.dart';
import '../domain/notifications.dart';
import 'notification_action_relay.dart';
import 'notification_buttons.dart';
import 'notification_payload.dart';

/// Where a button tapped outside the app's isolate goes (iOS, Android run it in a background engine, #211): a top
/// level `@pragma('vm:entry-point')` function of main.dart, the one place that wires the DI. Set before `start`.
DidReceiveBackgroundNotificationResponseCallback? backgroundActionEntry;

/// flutter_local_notifications (#39). Android, iOS and macOS: notifications, taps and cold start from a tap.
/// Windows: toasts and taps (cold start only for an MSIX-packaged app). Linux: notifications and taps while the app
/// runs (D-Bus), no cold start. Permission asked on iOS, macOS and Android 13+, not at [start].
/// One notification per message, grouped per Account (#238): Android's `groupKey` with a group summary «N nuovi
/// messaggi» from two messages on, the `threadIdentifier` on iOS and macOS (the system writes their summary); Windows
/// and Linux have no native group, nor a summary.
/// Up to two buttons (#211): in the app's isolate on macOS, Linux and Windows (which brings the app forward);
/// in a background engine on iOS and Android, relayed to the app's isolate when it runs ([relayToApp]).
@LazySingleton(as: Notifications, env: [Environment.prod])
class LocalNotifications() implements Notifications {
  final _plugin = FlutterLocalNotificationsPlugin();

  /// Broadcast: a tap during [start] is dropped, so the one Android delivers inside `initialize()` on a cold start
  /// never reaches a router that does not exist yet; that launch comes from [start]. A tap after [start] with nobody
  /// listening yet waits for the first listener ([_pending]).
  late final StreamController<NotificationTarget> _taps = StreamController.broadcast(
    onListen: () {
      final pending = _pending;
      _pending = null;
      if (pending != null) scheduleMicrotask(() => _taps.add(pending));
    },
  );

  /// The last tap after [start] while nobody listened: the engine kept by the Notifiche immediate (#214) started
  /// without the app on screen, so the Activity a tap opens hands it over before the router listens.
  NotificationTarget? _pending;

  /// Set once [start] read the launch: from then on a tap is not the launch.
  // ponytail: a tap on an older notification in the second a restarted service's engine spends in [start] is still
  // dropped (the app opens on the Posta unificata); buffer during [start] too, minus the launch, if it is ever seen.
  var _started = false;

  String _channelName = 'Postino';
  String Function(int count) _newMessages = (count) => '$count';

  /// Android: the notifications this isolate cancelled that a listing still showed. Android cancels asynchronously,
  /// so they do not count in a summary until a listing confirms them gone.
  final _cancelled = <int>{};

  ActionLabel _actionLabel = (action) => action.name;

  /// The app's isolate takes the buttons the background engine runs while it lives.
  ReceivePort? _relay;

  @override
  Future<NotificationTarget?> start({
    required String channelName,
    required String openLabel,
    required String Function(int count) newMessages,
    required String Function(NotificationAction action) actionLabel,
    required void Function(NotificationActionTap tap)? onAction,
  }) async {
    _channelName = channelName;
    _newMessages = newMessages;
    _actionLabel = actionLabel;
    final darwin = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestSoundPermission: false,
      requestBadgePermission: false,
      notificationCategories: darwinCategories(actionLabel),
    );
    _relay?.close();
    // Only the app's isolate takes the relayed buttons: a background task must not take the name from it.
    _relay = onAction == null ? null : listenForRelayedActions(onAction);
    await _plugin.initialize(
      settings: InitializationSettings(
        android: const AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: darwin,
        macOS: darwin,
        linux: LinuxInitializationSettings(defaultActionName: openLabel),
        windows: const WindowsInitializationSettings(
          appName: 'Postino',
          appUserModelId: 'cbucciarelli.Postino',
          guid: '63138c0f-1e11-489d-8009-27dfa772e307',
        ),
      ),
      onDidReceiveNotificationResponse: (r) {
        // Never an Azione on Android: the exported MainActivity takes this response from any app's Intent extras;
        // its real buttons run in the background engine ([backgroundActionEntry]). A spoofed one opens, like a tap.
        if (decodeAction(r.payload, r.actionId) case final tap? when !_android) return onAction?.call(tap);
        if (decodePayload(r.payload) case final target?) {
          if (_taps.hasListener) return _taps.add(target);
          if (_started) _pending = target;
        }
      },
      onDidReceiveBackgroundNotificationResponse: backgroundActionEntry,
    );
    final launch = await _plugin.getNotificationAppLaunchDetails();
    _started = true;
    if (!(launch?.didNotificationLaunchApp ?? false)) return null;
    final response = launch!.notificationResponse;
    // A button that launched the app (Windows, macOS): its Azione, and the app opens where it would. Not on Android,
    // where the launch Intent's extras can come from any app (see the response handler above).
    if (decodeAction(response?.payload, response?.actionId) case final tap? when !_android) {
      onAction?.call(tap);
      return null;
    }
    return decodePayload(response?.payload);
  }

  @override
  Future<void> show(MailNotification notification) async {
    final MailNotification(:conversation, :messageId, :accountAddress, :sender, :subject, :preview, :actions) =
        notification;
    final accountId = conversation.accountId;
    final body = [subject, preview].where((s) => s.isNotEmpty).join('\n');
    final id = notificationId(accountId, messageId);
    await _plugin.show(
      id: id,
      title: sender,
      body: body,
      payload: encodePayload(ConversationTarget(conversation)),
      notificationDetails: _details(conversation, body, actions),
    );
    _cancelled.remove(id);
  }

  @override
  Future<void> summarize(String accountId, String accountAddress, List<String> messageIds) async {
    if (!_android) return;
    await _summarize(
      accountId,
      address: accountAddress,
      coming: {for (final m in messageIds) notificationId(accountId, m)},
    );
  }

  @override
  Future<void> cancel(String accountId, Iterable<String> messageIds) async {
    final ids = {for (final m in messageIds) notificationId(accountId, m)};
    if (ids.isEmpty) return;
    // Where the OS lists them, only the shown ones: a sync may touch many messages without a notification.
    final active = switch (await _active()) {
      final list? => {for (final n in list) n.id},
      null => null,
    };
    for (final id in ids) {
      if (active == null || active.contains(id)) {
        await _plugin.cancel(id: id);
        if (_android) _cancelled.add(id);
      }
    }
    // Also when none was still shown: a button dismissed its notification itself, the summary may be left behind.
    if (_android) await _summarize(accountId);
  }

  @override
  Stream<NotificationTarget> get taps => _taps.stream;

  @override
  Future<bool> permissionNeeded() async {
    if (kIsWeb) return false;
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => !(await _androidPlugin?.areNotificationsEnabled() ?? true),
      TargetPlatform.iOS => !((await _ios?.checkPermissions())?.isEnabled ?? false),
      TargetPlatform.macOS => !((await _macos?.checkPermissions())?.isEnabled ?? false),
      _ => false,
    };
  }

  @override
  Future<bool> requestPermission() async {
    if (kIsWeb) return true;
    final granted = switch (defaultTargetPlatform) {
      TargetPlatform.android => await _androidPlugin?.requestNotificationsPermission(),
      TargetPlatform.iOS => await _ios?.requestPermissions(alert: true, sound: true, badge: true),
      TargetPlatform.macOS => await _macos?.requestPermissions(alert: true, sound: true, badge: true),
      _ => true,
    };
    return granted ?? false;
  }

  @override
  Future<void> openSystemSettings() async {
    if (kIsWeb) return;
    const mobileOrMac = {TargetPlatform.android, TargetPlatform.iOS, TargetPlatform.macOS};
    if (mobileOrMac.contains(defaultTargetPlatform)) await _plugin.openAppNotificationSettings();
  }

  /// A message's notification, in the group of its [conversation]'s Account; with the buttons of [actions] (#211).
  NotificationDetails _details(ConversationKey conversation, String body, List<NotificationAction> actions) {
    final accountId = conversation.accountId;
    final darwin = DarwinNotificationDetails(
      threadIdentifier: accountId,
      categoryIdentifier: darwinCategoryOf(actions),
    );
    return NotificationDetails(
      android: AndroidNotificationDetails(
        'new_mail',
        _channelName,
        importance: Importance.high,
        priority: Priority.high,
        category: AndroidNotificationCategory.email,
        groupKey: accountId,
        styleInformation: BigTextStyleInformation(body),
        actions: androidButtons(actions, _actionLabel),
      ),
      iOS: darwin,
      macOS: darwin,
      linux: LinuxNotificationDetails(actions: linuxButtons(actions, _actionLabel)),
      windows: WindowsNotificationDetails(actions: windowsButtons(conversation, actions, _actionLabel)),
    );
  }

  /// Android only: the group summary «N nuovi messaggi» of [accountId], N the notifications shown in its group and the
  /// [coming] ones about to be; none for one alone, and it goes with the last. Silent: its children alert. [address],
  /// its subtext, is the one it shows already when not given. Posted only when N changed: Android sheds the updates
  /// past a few per second.
  // ponytail: from two down to one it stays, «1 nuovo messaggio»: cancelling a summary takes its children with it.
  // ponytail: a post Android refuses (past 50 shown per app) still counts in [coming] until the next listing.
  Future<void> _summarize(String accountId, {String? address, Set<int> coming = const {}}) async {
    final summaryId = groupId(accountId);
    ActiveNotification? summary;
    final children = {...coming};
    final listed = <int>{};
    for (final n in await _active() ?? const <ActiveNotification>[]) {
      listed.add(n.id!);
      if (n.groupKey != accountId) continue;
      if (n.id == summaryId) {
        summary = n;
      } else if (!_cancelled.contains(n.id)) {
        children.add(n.id!);
      }
    }
    // Those no longer listed are gone for good.
    _cancelled.retainAll(listed);
    final count = children.length;
    if (count == 0) {
      if (summary != null) await _plugin.cancel(id: summaryId);
      return;
    }
    final subText = address ?? summary?.body;
    final title = _newMessages(count);
    if (subText == null || (count < 2 && summary == null) || summary?.title == title) return;
    await _plugin.show(
      id: summaryId,
      title: title,
      body: subText,
      payload: encodePayload(AccountTarget(accountId)),
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          'new_mail',
          _channelName,
          category: AndroidNotificationCategory.email,
          groupKey: accountId,
          setAsGroupSummary: true,
          groupAlertBehavior: GroupAlertBehavior.children,
          subText: subText,
        ),
      ),
    );
  }

  /// The notifications the OS shows now; null where it cannot list them by Account.
  Future<List<ActiveNotification>?> _active() async {
    if (!_canList) return null;
    try {
      return [
        for (final n in await _plugin.getActiveNotifications())
          if (n.id != null) n,
      ];
    } on Object catch (e) {
      debugPrint('[notifiche] active: ${e.runtimeType}');
      return null;
    }
  }

  /// Android, iOS and macOS list the shown notifications with their group.
  bool get _canList =>
      !kIsWeb &&
      const {TargetPlatform.android, TargetPlatform.iOS, TargetPlatform.macOS}.contains(defaultTargetPlatform);

  bool get _android => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  AndroidFlutterLocalNotificationsPlugin? get _androidPlugin =>
      _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  IOSFlutterLocalNotificationsPlugin? get _ios =>
      _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();

  MacOSFlutterLocalNotificationsPlugin? get _macos =>
      _plugin.resolvePlatformSpecificImplementation<MacOSFlutterLocalNotificationsPlugin>();
}
