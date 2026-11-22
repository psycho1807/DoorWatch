import 'dart:ui' as ui;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'prefs.dart';

/// Gestion des notifications push (FCM Android / APNs iOS) + locales.
class NotificationService {
  NotificationService._();

  static final _plugin = FlutterLocalNotificationsPlugin();

  static const _channelId   = 'doorbell';
  static const _channelName = 'Sonnette';
  static const _channelDesc = 'Alertes d\'appel à la porte';

  // ── Init ─────────────────────────────────────────────────────────────────

  static Future<void> init() async {
    // Canal Android haute priorité
    const androidChannel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDesc,
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);

    await _plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        ),
      ),
      onDidReceiveNotificationResponse: _onTap,
    );

    // Demander les permissions FCM
    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Écoute des messages en foreground
    FirebaseMessaging.onMessage.listen(_onForeground);

    // Écoute des taps quand l'app était en background
    FirebaseMessaging.onMessageOpenedApp.listen(_onMessageOpened);

    // Enregistrer / rafraîchir le token FCM
    final token = await messaging.getToken();
    if (token != null) {
      Prefs.fcmToken = token;
    }
    messaging.onTokenRefresh.listen((t) => Prefs.fcmToken = t);
  }

  // ── Affichage ────────────────────────────────────────────────────────────

  /// Affiche une notification locale "Quelqu'un est à la porte".
  static Future<void> showDoorbellNotification(RemoteMessage message) async {
    final title = message.notification?.title ?? 'Sonnette';
    final body  = message.notification?.body  ?? 'Quelqu\'un sonne à la porte';

    await _plugin.show(
      message.hashCode,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDesc,
          importance: Importance.max,
          priority: Priority.max,
          playSound: Prefs.notifySound,
          enableVibration: Prefs.notifyVibrate,
          icon: '@drawable/ic_doorbell',
          color: const ui.Color(0xFF1E88E5),
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          sound: 'doorbell.aiff',
        ),
      ),
      payload: message.data['entity_id'],
    );
  }

  // ── Handlers privés ──────────────────────────────────────────────────────

  static void _onForeground(RemoteMessage message) {
    showDoorbellNotification(message);
  }

  static void _onMessageOpened(RemoteMessage message) {
    // TODO : naviguer vers l'écran sonnette via le routeur global
  }

  static void _onTap(NotificationResponse response) {
    // TODO : naviguer vers l'écran sonnette
  }
}

