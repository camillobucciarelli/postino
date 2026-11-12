import 'dart:async';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:injectable/injectable.dart';

import '../domain/mail_notification.dart';
import '../domain/new_mail_summary.dart';
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
/// Grouped per Account (#210): Android's `groupKey` with a group notification titled with its address, the
/// `threadIdentifier` on iOS and macOS; Windows and Linux have no native group.
/// Up to two buttons (#211): in the app's isolate on macOS, Linux and Windows (which brings the app forward);
/// in a background engine on iOS and Android, relayed to the app's isolate when it runs ([relayToApp]).
@LazySingleton(as: Notifications, env: [Environment.prod])
class LocalNotifications() implements Notifications {
  final _plugin = FlutterLocalNotificationsPlugin();

  /// Broadcast: a tap before anyone listens is dropped, so the one Android delivers inside `initialize()` on a cold
  /// start never reaches a router that does not exist yet; that launch comes from [start].
  final _taps = StreamController<NotificationTarget>.broadcast();

  String _channelName = 'Postino';
  String Function(int count) _newMessages = (count) => '$count';

  /// Per Account, the notifications shown by this run: where the OS cannot list its own (Windows, Linux), the ones a
  /// summary replaces.
  // ponytail: in memory, so there a summary after a restart leaves the earlier ones; Android, iOS and macOS list them.
  final _shown = <String, Set<int>>{};

  ActionLabel _actionLabel = (action) => action.name;

  /// The app's isolate takes the buttons the background engine runs while it lives.
  ReceivePort? _relay;

  @override
  Future<NotificationTarget?> start({
    required String channelName,
    required String openLabel,
    required String Function(int count) newMessages,
    required String Function(NotificationAction action) actionLabel,
    required void Function(NotificationActionTap tap) onAction,
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
    _relay = listenForRelayedActions(onAction);
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
        if (decodeAction(r.payload, r.actionId) case final tap?) return onAction(tap);
        if (decodePayload(r.payload) case final target?) _taps.add(target);
      },
      onDidReceiveBackgroundNotificationResponse: backgroundActionEntry,
    );
    final launch = await _plugin.getNotificationAppLaunchDetails();
    if (!(launch?.didNotificationLaunchApp ?? false)) return null;
    final response = launch!.notificationResponse;
    // A button that launched the app (Windows, macOS): its Azione, and the app opens where it would.
    if (decodeAction(response?.payload, response?.actionId) case final tap?) {
      onAction(tap);
      return null;
    }
    return decodePayload(response?.payload);
  }

  @override
  Future<void> show(MailNotification notification) async {
    final MailNotification(:conversation, :accountAddress, :sender, :subject, :preview, :actions) = notification;
    final body = [subject, preview].where((s) => s.isNotEmpty).join('\n');
    // One per Conversazione: a newer message replaces its notification.
    final id = notificationId(conversation);
    await _plugin.show(
      id: id,
      title: sender,
      body: body,
      payload: encodePayload(ConversationTarget(conversation)),
      notificationDetails: _details(conversation.accountId, body, conversation: conversation, actions: actions),
    );
    (_shown[conversation.accountId] ??= {}).add(id);
    await _showGroup(conversation.accountId, accountAddress);
  }

  @override
  Future<void> showSummary(NewMailSummary summary) async {
    final NewMailSummary(:accountId, :accountAddress, :count) = summary;
    final ids = {...?_shown.remove(accountId)};
    for (final n in await _active() ?? const <ActiveNotification>[]) {
      // By group; by payload too (iOS, macOS) for those shown before the groups existed.
      final ofAccount = n.groupKey == accountId || decodePayload(n.payload)?.accountId == accountId;
      if (ofAccount && n.id != groupId(accountId)) ids.add(n.id!);
    }
    for (final id in ids) {
      await _plugin.cancel(id: id);
    }
    final title = _newMessages(count);
    await _plugin.show(
      id: summaryId(accountId),
      title: title,
      body: accountAddress,
      payload: encodePayload(AccountTarget(accountId)),
      notificationDetails: _details(accountId, accountAddress),
    );
    await _showGroup(accountId, accountAddress);
  }

  @override
  Future<void> cancel(List<NotificationTarget> targets) async {
    // Where the OS lists them, only the shown ones: a sync may touch many Conversazioni without a notification.
    final active = switch (await _active()) {
      final list? => {for (final n in list) n.id},
      null => null,
    };
    final gone = <int>{};
    for (final t in targets) {
      final id = idOf(t);
      _shown[t.accountId]?.remove(id);
      if (active == null || active.contains(id)) {
        await _plugin.cancel(id: id);
        gone.add(id);
      }
    }
    // Also when none was still shown: a button dismissed its notification itself, its group may be left empty.
    if (_android && targets.isNotEmpty) await _dropEmptyGroups(gone);
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

  /// A notification of [accountId], in its group; with the buttons of [actions] on [conversation] (#211).
  NotificationDetails _details(
    String accountId,
    String body, {
    ConversationKey? conversation,
    List<NotificationAction> actions = const [],
  }) {
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
      windows: conversation == null
          ? null
          : WindowsNotificationDetails(actions: windowsButtons(conversation, actions, _actionLabel)),
    );
  }

  /// Android only: the group notification of [accountId], titled with its address; silent, its children alert.
  Future<void> _showGroup(String accountId, String address) async {
    if (!_android) return;
    await _plugin.show(
      id: groupId(accountId),
      title: address,
      body: address,
      payload: encodePayload(AccountTarget(accountId)),
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          'new_mail',
          _channelName,
          category: AndroidNotificationCategory.email,
          groupKey: accountId,
          setAsGroupSummary: true,
          groupAlertBehavior: GroupAlertBehavior.children,
          subText: address,
        ),
      ),
    );
  }

  /// Android only: a group notification whose children are all gone goes too. [gone] were just cancelled: Android
  /// cancels asynchronously, so the listing may still show them.
  Future<void> _dropEmptyGroups(Set<int> gone) async {
    final active = [
      for (final n in await _active() ?? const <ActiveNotification>[])
        if (!gone.contains(n.id)) n,
    ];
    final withChildren = {
      for (final n in active)
        if (n.groupKey case final g? when n.id != groupId(g)) g,
    };
    for (final n in active) {
      if (n.groupKey case final g? when n.id == groupId(g) && !withChildren.contains(g)) {
        await _plugin.cancel(id: n.id!);
      }
    }
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
