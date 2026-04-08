import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import * as admin from 'firebase-admin';

@Injectable()
export class FirebaseService implements OnModuleInit {
  private readonly logger = new Logger(FirebaseService.name);
  private messaging!: admin.messaging.Messaging;

  constructor(private readonly config: ConfigService) {}

  onModuleInit() {
    if (!admin.apps.length) {
      admin.initializeApp({
        credential: admin.credential.cert({
          projectId: this.config.get<string>('firebase.projectId'),
          privateKey: this.config.get<string>('firebase.privateKey'),
          clientEmail: this.config.get<string>('firebase.clientEmail'),
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
    await this.messaging.send({
      token: fcmToken,
      // `notification` causes FCM to auto-display in the tray when app is
      // background/terminated on both Android and iOS.
      notification: { title, body },
      // `data` is always present so the Flutter app can route from any state.
      data,
      android: {
        priority: 'high',
        notification: {
          sound: 'default',
          channelId: 'easyrepair_bookings',
        },
      },
      apns: {
        headers: {
          // apns-priority 10 = immediate delivery (default is 5 = conserve battery).
          'apns-priority': '10',
          // apns-push-type must match content: 'alert' for user-visible notifications.
          'apns-push-type': 'alert',
        },
        payload: {
          aps: {
            sound: 'default',
            badge: 1,
            // content-available: 1 allows background fetch on iOS so the app
            // can refresh its notification state even before the user taps.
            'content-available': 1,
          },
        },
      },
    });
  }
}
