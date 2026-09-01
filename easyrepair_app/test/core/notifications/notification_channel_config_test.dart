import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:handygo_app/core/notifications/local_notification_service.dart';

/// FIX 5 — notifications arriving silently.
///
/// An Android notification channel is created once per install; its importance
/// and sound cannot be changed afterwards by the app. So the fix for a channel
/// that ended up silent on real devices is a NEW id, and the invariant worth
/// protecting is that every place naming a channel keeps naming the same one.
/// A background/terminated push reaches the device through the MANIFEST's
/// default channel and through the backend's explicit `channelId`; if either
/// drifts from the ids created here, FCM silently falls back to its own
/// "Miscellaneous" channel and the sound problem comes straight back.
void main() {
  String read(String path) => File(path).readAsStringSync();

  test('the two channels are distinct and versioned', () {
    expect(LocalNotificationService.channelId, 'handygo_bookings_v2');
    expect(LocalNotificationService.chatChannelId, 'handygo_chat_v2');
    expect(
      LocalNotificationService.channelId,
      isNot(LocalNotificationService.chatChannelId),
    );
  });

  test('the superseded ids are retired, and only those', () {
    expect(LocalNotificationService.retiredChannelIds, [
      'easyrepair_bookings',
      'easyrepair_chat',
    ]);
    // Retiring a live id would delete the channel the app just created.
    expect(
      LocalNotificationService.retiredChannelIds,
      isNot(contains(LocalNotificationService.channelId)),
    );
    expect(
      LocalNotificationService.retiredChannelIds,
      isNot(contains(LocalNotificationService.chatChannelId)),
    );
  });

  test("AndroidManifest's FCM default channel matches the created one", () {
    final manifest = read('android/app/src/main/AndroidManifest.xml');
    final match = RegExp(
      r'com\.google\.firebase\.messaging\.default_notification_channel_id"'
      r'[\s\S]*?android:value="([^"]+)"',
    ).firstMatch(manifest);

    expect(match, isNotNull, reason: 'FCM default channel meta-data is gone');
    expect(match!.group(1), LocalNotificationService.channelId);
  });

  test('foreground and FCM notifications use the monochrome HandyGo icon', () {
    expect(
      LocalNotificationService.androidSmallIcon,
      '@drawable/ic_stat_handygo',
    );

    final manifest = read('android/app/src/main/AndroidManifest.xml');
    expect(
      manifest,
      contains(
        'android:name="com.google.firebase.messaging.default_notification_icon"',
      ),
    );
    expect(manifest, contains('android:resource="@drawable/ic_stat_handygo"'));

    for (final density in <String>[
      'mdpi',
      'hdpi',
      'xhdpi',
      'xxhdpi',
      'xxxhdpi',
    ]) {
      expect(
        File(
          'android/app/src/main/res/drawable-$density/ic_stat_handygo.png',
        ).existsSync(),
        isTrue,
        reason: 'missing $density notification drawable',
      );
    }
  });

  test('no retired id is still referenced by the manifest', () {
    final manifest = read('android/app/src/main/AndroidManifest.xml');
    for (final retired in LocalNotificationService.retiredChannelIds) {
      expect(manifest, isNot(contains(retired)));
    }
  });

  test("the backend's push channel ids match this app's", () {
    // Same repo, so the one place that could silently drift is checked here
    // rather than left to a real device to discover.
    final backend = File('../backend/src/firebase/firebase.service.ts');
    if (!backend.existsSync()) return; // app checked out on its own
    final source = backend.readAsStringSync();

    expect(source, contains("'${LocalNotificationService.channelId}'"));
    expect(source, contains("'${LocalNotificationService.chatChannelId}'"));
    for (final retired in LocalNotificationService.retiredChannelIds) {
      expect(source, isNot(contains("'$retired'")));
    }
  });
}
