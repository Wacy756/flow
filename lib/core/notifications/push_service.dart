import 'dart:developer' as dev;
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ============================================================
// Push notification service — wraps Firebase Messaging and
// flutter_local_notifications.
//
// FIREBASE SETUP REQUIRED:
//   Android: place google-services.json in android/app/
//   iOS:     place GoogleService-Info.plist in ios/Runner/
//   Then run: flutterfire configure
//
// The static [pendingDeepLink] is used to hand off notification
// taps to the dashboard when the app launches from terminated.
// ============================================================

/// Holds a deep-link target that arrived while the app was cold-started.
/// Dashboards check and clear this in their [initState].
class PushDeepLink {
  PushDeepLink._();
  static String? incidentId;
  static String? tenancyId;
}

// Top-level handler required by FCM for background/terminated messages.
@pragma('vm:entry-point')
Future<void> _onBackgroundMessage(RemoteMessage message) async {
  // System tray notification already shown by FCM automatically.
  // Store deep-link data so it's available when the app opens.
  _storeDeepLink(message.data);
}

void _storeDeepLink(Map<String, dynamic> data) {
  final incidentId = data['incident_id'] as String?;
  final tenancyId  = data['tenancy_id']  as String?;
  if (incidentId != null) PushDeepLink.incidentId = incidentId;
  if (tenancyId  != null) PushDeepLink.tenancyId  = tenancyId;
}

// ── Notification channels ───────────────────────────────────

const _kDefaultChannel = AndroidNotificationChannel(
  'flow_default',
  'Flow Notifications',
  description: 'Property management updates from Flow',
  importance: Importance.high,
);

// ── PushService ─────────────────────────────────────────────

class PushService {
  PushService._();

  static final _local = FlutterLocalNotificationsPlugin();
  static bool _initialised = false;

  /// Call once from [main] after Firebase.initializeApp().
  static Future<void> init() async {
    if (_initialised) return;
    _initialised = true;

    // ── 1. Local notifications (foreground display) ──
    await _local.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_kDefaultChannel);

    await _local.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );

    // ── 2. Background handler ──
    FirebaseMessaging.onBackgroundMessage(_onBackgroundMessage);

    // ── 3. Request permission ──
    final messaging = FirebaseMessaging.instance;
    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    dev.log(
      'Push permission: ${settings.authorizationStatus}',
      name: 'PushService',
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional) {
      await _registerToken(messaging);
    }

    // ── 4. Foreground messages → local notification ──
    FirebaseMessaging.onMessage.listen(_showForegroundNotification);

    // ── 5. Background tap (app was backgrounded) ──
    FirebaseMessaging.onMessageOpenedApp.listen((msg) {
      _storeDeepLink(msg.data);
    });

    // ── 6. Terminated state tap ──
    final initial = await messaging.getInitialMessage();
    if (initial != null) {
      _storeDeepLink(initial.data);
    }
  }

  // ── Token registration ────────────────────────────────────

  static Future<void> _registerToken(FirebaseMessaging messaging) async {
    try {
      final token = await messaging.getToken();
      if (token == null) return;
      await _upsertToken(token);

      // Refresh on rotation
      messaging.onTokenRefresh.listen((newToken) {
        _upsertToken(newToken).catchError((e) {
          dev.log('Token refresh upsert failed: $e', name: 'PushService');
        });
      });
    } catch (e, st) {
      dev.log('Token registration failed', name: 'PushService', error: e, stackTrace: st);
    }
  }

  static Future<void> _upsertToken(String token) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    final platform = Platform.isIOS ? 'ios' : 'android';

    await Supabase.instance.client.from('fcm_tokens').upsert(
      {'user_id': userId, 'token': token, 'platform': platform},
      onConflict: 'user_id, token',
    );
    dev.log('FCM token registered ($platform)', name: 'PushService');
  }

  /// Call on sign-out to clean up this device's token.
  static Future<void> removeToken() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;

      await Supabase.instance.client
          .from('fcm_tokens')
          .delete()
          .eq('user_id', userId)
          .eq('token', token);

      await FirebaseMessaging.instance.deleteToken();
    } catch (e, st) {
      dev.log('removeToken failed', name: 'PushService', error: e, stackTrace: st);
    }
  }

  // ── Foreground display ────────────────────────────────────

  static Future<void> _showForegroundNotification(
      RemoteMessage message) async {
    final n = message.notification;
    if (n == null) return;

    await _local.show(
      n.hashCode,
      n.title,
      n.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _kDefaultChannel.id,
          _kDefaultChannel.name,
          channelDescription: _kDefaultChannel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );

    // Also store deep-link in case user taps the local notification
    _storeDeepLink(message.data);
  }
}
