import Flutter
import UIKit

/// Minimal AppDelegate — all notification handling is managed by the
/// flutter_local_notifications and firebase_messaging plugins.
///
/// DO NOT set UNUserNotificationCenter.current().delegate here manually.
/// flutter_local_notifications sets itself as the delegate during
/// FlutterLocalNotificationsPlugin registration and forwards unhandled
/// notifications to the previously-installed delegate (firebase_messaging).
/// Overriding the delegate after registration breaks that chain.
///
/// iOS foreground FCM visibility is controlled in Dart via:
///   FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(...)
@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
