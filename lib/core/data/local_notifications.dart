import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:injectable/injectable.dart';

import '../domain/mail_notification.dart';
import '../domain/notifications.dart';
import 'notification_payload.dart';

/// flutter_local_notifications (#39). Android, iOS and macOS: notifications, taps and cold start from a tap.
/// Windows: toasts and taps (cold start only for an MSIX-packaged app). Linux: notifications and taps while the app
/// runs (D-Bus), no cold start. Permission asked on iOS, macOS and Android 13+, not at [start].
@LazySingleton(as: Notifications, env: [Environment.prod])
class LocalNotifications() implements Notifications {
  final _plugin = FlutterLocalNotificationsPlugin();

  /// Broadcast: a tap before anyone listens is dropped, so the one Android delivers inside `initialize()` on a cold
  /// start never reaches a router that does not exist yet; that launch comes from [start].
  final _taps = StreamController<ConversationKey>.broadcast();

  String _channelName = 'Postino';

  @override
  Future<ConversationKey?> start({required String channelName, required String openLabel}) async {
    _channelName = channelName;
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
        if (decodePayload(r.payload) case final key?) _taps.add(key);
      },
    );
    final launch = await _plugin.getNotificationAppLaunchDetails();
    return launch?.didNotificationLaunchApp ?? false ? decodePayload(launch!.notificationResponse?.payload) : null;
  }

  @override
  Future<void> show(MailNotification notification) {
    final MailNotification(:conversation, :sender, :subject, :preview) = notification;
    final body = [subject, preview].where((s) => s.isNotEmpty).join('\n');
    return _plugin.show(
      // One per Conversazione: a newer message replaces its notification.
      id: Object.hash(conversation.accountId, conversation.conversationId) & 0x7fffffff,
      title: sender,
      body: body,
      payload: encodePayload(conversation),
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          'new_mail',
          _channelName,
          importance: Importance.high,
          priority: Priority.high,
          category: AndroidNotificationCategory.email,
          styleInformation: BigTextStyleInformation(body),
        ),
      ),
    );
  }

  @override
  Stream<ConversationKey> get taps => _taps.stream;

  @override
  Future<bool> permissionNeeded() async {
    if (kIsWeb) return false;
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => !(await _android?.areNotificationsEnabled() ?? true),
      TargetPlatform.iOS => !((await _ios?.checkPermissions())?.isEnabled ?? false),
      TargetPlatform.macOS => !((await _macos?.checkPermissions())?.isEnabled ?? false),
      _ => false,
    };
  }

  @override
  Future<bool> requestPermission() async {
    if (kIsWeb) return true;
    final granted = switch (defaultTargetPlatform) {
      TargetPlatform.android => await _android?.requestNotificationsPermission(),
      TargetPlatform.iOS => await _ios?.requestPermissions(alert: true, sound: true, badge: true),
      TargetPlatform.macOS => await _macos?.requestPermissions(alert: true, sound: true, badge: true),
      _ => true,
    };
    return granted ?? false;
  }

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  IOSFlutterLocalNotificationsPlugin? get _ios =>
      _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();

  MacOSFlutterLocalNotificationsPlugin? get _macos =>
      _plugin.resolvePlatformSpecificImplementation<MacOSFlutterLocalNotificationsPlugin>();
}
