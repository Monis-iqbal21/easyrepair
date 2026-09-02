import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import * as admin from 'firebase-admin';

/**
 * HandyGo's brand teal, as Android's notification accent.
 *
 * The backend has no design system of its own, so this is the one place the
 * value is written on this side. It is the same #11645D as
 * `AppSemanticColors.primary` in the Flutter app, as the launcher tile in
 * `assets/images/logo-final.png`, and as `@color/ic_launcher_background` in
 * the Android resources. Change it in all four or in none.
 */
const HANDYGO_NOTIFICATION_ACCENT = '#11645D';

@Injectable()
export class FirebaseService implements OnModuleInit {
  private readonly logger = new Logger(FirebaseService.name);
  private messaging?: admin.messaging.Messaging;

  constructor(private readonly config: ConfigService) {}

  onModuleInit() {
    const projectId = this.config.get<string>('firebase.projectId');
    const clientEmail = this.config.get<string>('firebase.clientEmail');
    const privateKey = this.config
      .get<string>('firebase.privateKey')
      ?.replace(/\\n/g, '\n');

    if (!projectId || !clientEmail || !privateKey) {
      this.logger.warn(
        'Firebase Admin not initialized. Missing firebase.projectId, firebase.clientEmail, or firebase.privateKey.',
      );
      return;
    }

    if (!admin.apps.length) {
      admin.initializeApp({
        credential: admin.credential.cert({
          projectId,
          clientEmail,
          privateKey,
        }),
      });
    }

    this.messaging = admin.messaging();
    this.logger.log('Firebase Admin initialized');
  }

  async sendPush(
    fcmToken: string,
    title: string,
    body: string,
    data?: Record<string, string>,
  ): Promise<void> {
    if (!this.messaging) {
      this.logger.warn('Firebase messaging is not initialized. Skipping push.');
      return;
    }

    const isChat =
      data?.conversationId != null ||
      data?.entityType === 'conversation' ||
      (data?.eventKey ?? '').startsWith('chat');
    // Must match LocalNotificationService's channel ids. The `_v2` suffix is
    // the notification-sound fix: an Android channel's importance and sound
    // are fixed at creation, so a device whose original `easyrepair_*`
    // channel had ended up silent could only be recovered with a new id.
    //
    // Backward compatible with an APK that predates those ids: Firebase falls
    // back to that app's manifest default channel and, failing that, creates
    // `fcm_fallback_notification_channel` at IMPORTANCE_DEFAULT -- so an old
    // client still receives, and still hears, the push. It only loses the
    // chat/bookings split until it updates.
    const androidChannelId = isChat
      ? 'handygo_chat_v2'
      : 'handygo_bookings_v2';

    await this.messaging.send({
      token: fcmToken,
      notification: { title, body },
      data,
      android: {
        priority: 'high',
        notification: {
          sound: 'default',
          channelId: androidChannelId,
          // Brand accent for the small icon and the app-name line. The icon
          // itself comes from the manifest's default_notification_icon
          // (@drawable/ic_stat_handygo) and is a monochrome silhouette by
          // platform rule, so this is the only place HandyGo's colour reaches
          // a push that lands while the app is not running. Mirrors
          // LocalNotificationService.androidAccent on the Flutter side.
          color: HANDYGO_NOTIFICATION_ACCENT,
        },
      },
      apns: {
        headers: {
          'apns-priority': '10',
          'apns-push-type': 'alert',
        },
        payload: {
          aps: {
            sound: 'default',
            badge: 1,
            'content-available': 1,
          },
        },
      },
    });
  }
}
