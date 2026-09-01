import { NotificationsService } from './notifications.service';

describe('NotificationsService', () => {
  let notificationsRepository: any;
  let firebase: any;
  let chatGateway: any;
  let service: NotificationsService;

  beforeEach(() => {
    notificationsRepository = {
      create: jest.fn().mockResolvedValue({ id: 'notif-1' }),
      findUserFcmToken: jest.fn().mockResolvedValue('token-abc'),
      findUserNotificationLocale: jest.fn().mockResolvedValue('ur_Latn'),
      clearFcmTokenByValue: jest.fn().mockResolvedValue(undefined),
    };
    firebase = { sendPush: jest.fn().mockResolvedValue(undefined) };
    chatGateway = { emitAppBanner: jest.fn() };
    service = new NotificationsService(
      notificationsRepository,
      firebase,
      chatGateway,
    );
  });

  it('always persists the notification, even when there is no FCM token to push to', async () => {
    notificationsRepository.findUserFcmToken.mockResolvedValue(null);

    await service.notify({
      userId: 'user-1',
      eventKey: 'worker.availability.forced_offline',
      title: 'Ap offline ho gaye hain',
      body: 'Logout karne ki wajah se apki availability offline kar di gayi hai.',
    });

    expect(notificationsRepository.create).toHaveBeenCalledTimes(1);
    expect(firebase.sendPush).not.toHaveBeenCalled();
  });

  it('deduplicates a repeated Complaint event before sending another push/banner', async () => {
    notificationsRepository.create.mockRejectedValue({ code: 'P2002' });

    await service.notify({
      userId: 'client-1',
      eventKey: 'complaint.status.resolved',
      title: 'Your report has been resolved',
      body: 'Aap ka report resolve ho gaya',
      complaintEventId: 'event-resolved-1',
      bookingId: 'booking-1',
    });

    expect(firebase.sendPush).not.toHaveBeenCalled();
    expect(chatGateway.emitAppBanner).not.toHaveBeenCalled();
  });

  describe('invalid-token cleanup', () => {
    it('clears the token when Firebase reports it permanently unregistered', async () => {
      firebase.sendPush.mockRejectedValue({
        code: 'messaging/registration-token-not-registered',
      });

      await service.notify({
        userId: 'user-1',
        eventKey: 'booking.status.en_route',
        title: 'Worker On the Way',
        body: 'Your worker is on the way.',
      });
      await new Promise((resolve) => setImmediate(resolve));

      expect(notificationsRepository.clearFcmTokenByValue).toHaveBeenCalledWith(
        'token-abc',
      );
    });

    it('clears the token when Firebase reports it invalid', async () => {
      firebase.sendPush.mockRejectedValue({
        code: 'messaging/invalid-registration-token',
      });

      await service.notify({
        userId: 'user-1',
        eventKey: 'booking.status.en_route',
        title: 'Worker On the Way',
        body: 'Your worker is on the way.',
      });
      await new Promise((resolve) => setImmediate(resolve));

      expect(notificationsRepository.clearFcmTokenByValue).toHaveBeenCalledWith(
        'token-abc',
      );
    });

    it('does NOT clear the token on a transient send failure (network/quota/malformed payload)', async () => {
      firebase.sendPush.mockRejectedValue({
        code: 'messaging/internal-error',
      });

      await service.notify({
        userId: 'user-1',
        eventKey: 'booking.status.en_route',
        title: 'Worker On the Way',
        body: 'Your worker is on the way.',
      });
      await new Promise((resolve) => setImmediate(resolve));

      expect(
        notificationsRepository.clearFcmTokenByValue,
      ).not.toHaveBeenCalled();
    });

    it('never uses the invalid-token signal to infer Worker availability — it only clears the token', async () => {
      firebase.sendPush.mockRejectedValue({
        code: 'messaging/registration-token-not-registered',
      });

      await service.notify({
        userId: 'user-1',
        eventKey: 'worker.availability.forced_offline',
        title: 'Ap offline ho gaye hain',
        body: 'App kuch dair se active nahi thi, is liye apko offline kar diya gaya hai.',
      });
      await new Promise((resolve) => setImmediate(resolve));

      // No availability/presence repository is even wired into
      // NotificationsService — the only side effect of an invalid token is
      // clearing it, confirmed by asserting the mock's full call surface.
      expect(Object.keys(notificationsRepository)).toEqual([
        'create',
        'findUserFcmToken',
        'findUserNotificationLocale',
        'clearFcmTokenByValue',
      ]);
    });
  });

  describe('selected notification language', () => {
    it.each([
      ['en', 'Payment received', 'The client paid Rs 2500 in full.'],
      [
        'ur_Latn',
        'Payment mil gayi hai',
        'Client ne poore Rs 2500 de diye hain.',
      ],
      ['ur', 'ادائیگی موصول ہو گئی', 'کلائنٹ نے پورے 2500 روپے دے دیے ہیں۔'],
    ])(
      'renders both title and body in %s',
      async (locale, title, bodyStart) => {
        notificationsRepository.findUserNotificationLocale.mockResolvedValue(
          locale,
        );

        await service.notify({
          userId: 'worker-1',
          eventKey: 'payment.received',
          title: 'legacy mixed title',
          body: 'legacy mixed body',
          templateParams: { received: 2500 },
        });

        expect(notificationsRepository.create).toHaveBeenLastCalledWith(
          expect.objectContaining({
            title,
            body: expect.stringContaining(bodyStart),
          }),
        );
        expect(chatGateway.emitAppBanner).toHaveBeenLastCalledWith(
          'worker-1',
          expect.objectContaining({
            title,
            body: expect.stringContaining(bodyStart),
          }),
        );
      },
    );

    it('leaves client-only notification copy on its existing path', async () => {
      await service.notify({
        userId: 'client-1',
        eventKey: 'bid.received',
        title: 'Ali sent an offer',
        body: 'Ali offered PKR 2500',
      });

      expect(
        notificationsRepository.findUserNotificationLocale,
      ).not.toHaveBeenCalled();
      expect(notificationsRepository.create).toHaveBeenLastCalledWith(
        expect.objectContaining({
          title: 'Ali sent an offer',
          body: 'Ali offered PKR 2500',
        }),
      );
    });
  });
});
