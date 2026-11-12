import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:injectable/injectable.dart';

import '../domain/mail_notification.dart';
import '../domain/new_mail_summary.dart';
import '../domain/notification_target.dart';
import '../domain/notifications.dart';
import 'notification_payload.dart';

/// flutter_local_notifications (#39). Android, iOS and macOS: notifications, taps and cold start from a tap.
/// Windows: toasts and taps (cold start only for an MSIX-packaged app). Linux: notifications and taps while the app
/// runs (D-Bus), no cold start. Permission asked on iOS, macOS and Android 13+, not at [start].
/// Grouped per Account (#210): Android's `groupKey` with a group notification titled with its address, the
/// `threadIdentifier` on iOS and macOS; Windows and Linux have no native group.
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

  @override
  Future<NotificationTarget?> start({
    required String channelName,
    required String openLabel,
    required String Function(int count) newMessages,
  }) async {
    _channelName = channelName;
    _newMessages = newMessages;
    const darwin = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestSoundPermission: false,
      requestBadgePermission: false,
    );
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
        if (decodePayload(r.payload) case final target?) _taps.add(target);
      },
    );
    final launch = await _plugin.getNotificationAppLaunchDetails();
    return launch?.didNotificationLaunchApp ?? false ? decodePayload(launch!.notificationResponse?.payload) : null;
  }

  @override
  Future<void> show(MailNotification notification) async {
    final MailNotification(:conversation, :accountAddress, :sender, :subject, :preview) = notification;
    final body = [subject, preview].where((s) => s.isNotEmpty).join('\n');
    // One per Conversazione: a newer message replaces its notification.
    final id = notificationId(conversation);
    await _plugin.show(
      id: id,
      title: sender,
      body: body,
      payload: encodePayload(ConversationTarget(conversation)),
      notificationDetails: _details(conversation.accountId, body),
    );
    (_shown[conversation.accountId] ??= {}).add(id);
    await _showGroup(conversation.accountId, accountAddress);
  }

  @override
  Future<void> showSummary(NewMailSummary summary) async {
    final NewMailSummary(:accountId, :accountAddress, :count) = summary;
    final ids = {...?_shown.remove(accountId)};
    for (final n in await _active() ?? const <ActiveNotification>[]) {
      if (n.groupKey == accountId && n.id != groupId(accountId)) ids.add(n.id!);
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
    for (final t in targets) {
      final id = idOf(t);
      _shown[t.accountId]?.remove(id);
      if (active == null || active.contains(id)) await _plugin.cancel(id: id);
    }
    if (_android) await _dropEmptyGroups();
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

  /// A notification of [accountId], in its group.
  NotificationDetails _details(String accountId, String body) => NotificationDetails(
    android: AndroidNotificationDetails(
      'new_mail',
      _channelName,
      importance: Importance.high,
      priority: Priority.high,
      category: AndroidNotificationCategory.email,
      groupKey: accountId,
      styleInformation: BigTextStyleInformation(body),
    ),
    iOS: DarwinNotificationDetails(threadIdentifier: accountId),
    macOS: DarwinNotificationDetails(threadIdentifier: accountId),
  );

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

  /// Android only: a group notification whose children are all gone goes too.
  Future<void> _dropEmptyGroups() async {
    final active = await _active() ?? const <ActiveNotification>[];
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
