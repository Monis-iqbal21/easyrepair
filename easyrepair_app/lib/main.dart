import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/notifications/local_notification_service.dart';
import 'firebase_options.dart';

/// Top-level FCM background handler — runs in a separate Dart isolate.
/// Firebase must be re-initialized here; no UI or Riverpod access.
/// The system tray notification is shown automatically by FCM when the
/// message payload contains a [notification] block.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Register the background message handler before any other Firebase call.
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Request notification permissions (prompts user on Android 13+ and iOS).
  await FirebaseMessaging.instance.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  // iOS only: show system banner/sound/badge when a FCM notification arrives
  // while the app is in the foreground.
  // On Android, foreground visibility is handled by LocalNotificationService.
  if (Platform.isIOS) {
    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  // Initialize flutter_local_notifications: creates the Android channel and
  // checks for a terminated-launch payload from a previously shown notification.
  // Must run before runApp so the channel exists before FCM delivers a
  // background notification.
  await LocalNotificationService.instance.init();

  runApp(const ProviderScope(child: EasyRepairApp()));
}
