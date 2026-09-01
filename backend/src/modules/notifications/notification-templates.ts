export const NOTIFICATION_KEYS = {
  BOOKING_ASSIGNED: 'booking.assigned',
  BID_RECEIVED: 'bid.received',
  BID_ACCEPTED: 'bid.accepted',
  BOOKING_STATUS_EN_ROUTE: 'booking.status.en_route',
  BOOKING_STATUS_IN_PROGRESS: 'booking.status.in_progress',
  BOOKING_COMPLETED: 'booking.completed',
  BOOKING_CANCELLED_BY_CLIENT: 'booking.cancelled.by_client',
  BOOKING_CANCELLED_BY_WORKER: 'booking.cancelled.by_worker',
  BOOKING_REVIEW_CREATED: 'booking.review.created',
  INSPECTION_CLOSED: 'booking.inspection.closed',
  INSPECTION_QUOTE_ACCEPTED: 'booking.inspection.quote_accepted',
  WORKER_AUTO_OFFLINE: 'worker.auto_offline',
  WORKER_FORCED_OFFLINE: 'worker.availability.forced_offline',
  WORKER_ONBOARDING_APPROVED: 'worker.onboarding.approved',
  WORKER_ONBOARDING_CHANGES_REQUIRED: 'worker.onboarding.changes_required',
  STANDARD_JOB_LISTED: 'booking.standard.worker_listed',
  INSPECTION_JOB_AVAILABLE: 'booking.inspection.available',
  BIDDING_JOB_AVAILABLE: 'booking.bidding.available',
  FIND_OTHER_USTAAD_AVAILABLE: 'booking.inspection.find_other_ustaad_available',
  WORKER_VERIFIED: 'worker.verified',
  PAYMENT_RECEIVED: 'payment.received',
  PAYMENT_SHORT: 'payment.short',
} as const;

export type NotificationKey =
  (typeof NOTIFICATION_KEYS)[keyof typeof NOTIFICATION_KEYS];
export type NotificationLocale = 'en' | 'ur' | 'ur_Latn';

// Only worker-recipient events belong to the locale fix. Client notification
// copy remains authored by its existing service branches, including dynamic
// bid/status wording that must not be replaced by a generic template.
const localizedKeys = new Set<string>([
  NOTIFICATION_KEYS.BOOKING_ASSIGNED,
  NOTIFICATION_KEYS.BID_ACCEPTED,
  NOTIFICATION_KEYS.BOOKING_CANCELLED_BY_CLIENT,
  NOTIFICATION_KEYS.BOOKING_REVIEW_CREATED,
  NOTIFICATION_KEYS.INSPECTION_CLOSED,
  NOTIFICATION_KEYS.INSPECTION_QUOTE_ACCEPTED,
  NOTIFICATION_KEYS.WORKER_AUTO_OFFLINE,
  NOTIFICATION_KEYS.WORKER_FORCED_OFFLINE,
  NOTIFICATION_KEYS.WORKER_ONBOARDING_APPROVED,
  NOTIFICATION_KEYS.WORKER_ONBOARDING_CHANGES_REQUIRED,
  NOTIFICATION_KEYS.STANDARD_JOB_LISTED,
  NOTIFICATION_KEYS.INSPECTION_JOB_AVAILABLE,
  NOTIFICATION_KEYS.BIDDING_JOB_AVAILABLE,
  NOTIFICATION_KEYS.FIND_OTHER_USTAAD_AVAILABLE,
  NOTIFICATION_KEYS.WORKER_VERIFIED,
  NOTIFICATION_KEYS.PAYMENT_RECEIVED,
  NOTIFICATION_KEYS.PAYMENT_SHORT,
]);

export function hasLocalizedNotificationTemplate(eventKey: string): boolean {
  return localizedKeys.has(eventKey);
}

export function normalizeNotificationLocale(
  locale: string | null | undefined,
): NotificationLocale {
  return locale === 'en' || locale === 'ur' || locale === 'ur_Latn'
    ? locale
    : 'ur_Latn';
}

type Copy = { title: string; body: string };
type Copies = Record<NotificationLocale, Copy>;
const pick = (locale: NotificationLocale, copies: Copies): Copy =>
  copies[locale];

export function getNotificationTemplate(
  eventKey: string,
  params: Record<string, string | number> = {},
  requestedLocale: string = 'ur_Latn',
): Copy {
  const locale = normalizeNotificationLocale(requestedLocale);
  const reason = String(params.reason ?? '').trim();
  const clientName = String(params.clientName ?? '').trim() || 'Client';

  switch (eventKey) {
    case NOTIFICATION_KEYS.BOOKING_ASSIGNED:
      return pick(locale, {
        en: {
          title: 'New job assigned',
          body: 'You have been assigned a new job. Open the app for details.',
        },
        ur_Latn: {
          title: 'Naya kaam assign hua hai',
          body: 'Aapko naya kaam assign hua hai. Tafseel app mein dekhein.',
        },
        ur: {
          title: 'نیا کام تفویض ہوا ہے',
          body: 'آپ کو نیا کام تفویض ہوا ہے۔ تفصیل ایپ میں دیکھیں۔',
        },
      });
    case NOTIFICATION_KEYS.BID_ACCEPTED:
      return pick(locale, {
        en: {
          title: 'Offer accepted',
          body: 'Your offer has been accepted. Open the job details.',
        },
        ur_Latn: {
          title: 'Offer accept ho gayi',
          body: 'Aapki offer accept ho gayi hai. Kaam ki tafseel dekhein.',
        },
        ur: {
          title: 'آفر قبول ہو گئی',
          body: 'آپ کی آفر قبول ہو گئی ہے۔ کام کی تفصیل دیکھیں۔',
        },
      });
    case NOTIFICATION_KEYS.BOOKING_CANCELLED_BY_CLIENT:
      return pick(locale, {
        en: {
          title: 'Job cancelled',
          body: reason
            ? `The client cancelled the job. Reason: ${reason}`
            : 'The client cancelled the job.',
        },
        ur_Latn: {
          title: 'Kaam cancel ho gaya',
          body: reason
            ? `Client ne kaam cancel kar diya. Wajah: ${reason}`
            : 'Client ne kaam cancel kar diya hai.',
        },
        ur: {
          title: 'کام منسوخ ہو گیا',
          body: reason
            ? `کلائنٹ نے کام منسوخ کر دیا۔ وجہ: ${reason}`
            : 'کلائنٹ نے کام منسوخ کر دیا ہے۔',
        },
      });
    case NOTIFICATION_KEYS.BOOKING_REVIEW_CREATED:
      return pick(locale, {
        en: {
          title: 'New review received',
          body: `${clientName} left a review for your work. Open the app to view it.`,
        },
        ur_Latn: {
          title: 'Aapko naya review mila hai',
          body: `${clientName} ne aapke kaam ka review diya hai. App mein dekhein.`,
        },
        ur: {
          title: 'آپ کو نیا ریویو ملا ہے',
          body: `${clientName} نے آپ کے کام کا ریویو دیا ہے۔ ایپ میں دیکھیں۔`,
        },
      });
    case NOTIFICATION_KEYS.BOOKING_COMPLETED:
      return {
        title: 'Job Completed',
        body: 'Your worker has completed the job. Please leave a review.',
      };
    case NOTIFICATION_KEYS.INSPECTION_CLOSED:
      return pick(locale, {
        en: {
          title: 'Inspection closed',
          body: 'The client closed the job after the inspection.',
        },
        ur_Latn: {
          title: 'Inspection band ho gayi',
          body: 'Client ne inspection ke baad kaam band kar diya hai.',
        },
        ur: {
          title: 'معائنہ بند ہو گیا',
          body: 'کلائنٹ نے معائنے کے بعد کام بند کر دیا ہے۔',
        },
      });
    case NOTIFICATION_KEYS.INSPECTION_QUOTE_ACCEPTED:
      return pick(locale, {
        en: {
          title: 'Quote accepted',
          body: 'The client accepted your quote. Continue the repair.',
        },
        ur_Latn: {
          title: 'Quote accept ho gaya hai',
          body: 'Client ne aapka quote accept kar liya hai. Repair jari rakhein.',
        },
        ur: {
          title: 'قیمت قبول ہو گئی',
          body: 'کلائنٹ نے آپ کی قیمت قبول کر لی ہے۔ مرمت جاری رکھیں۔',
        },
      });
    case NOTIFICATION_KEYS.PAYMENT_RECEIVED:
      return pick(locale, {
        en: {
          title: 'Payment received',
          body:
            params.received != null
              ? `The client paid Rs ${params.received} in full. Open the app to view your earning.`
              : 'The client paid in full. Open the app to view your earning.',
        },
        ur_Latn: {
          title: 'Payment mil gayi hai',
          body:
            params.received != null
              ? `Client ne poore Rs ${params.received} de diye hain. Apni kamai app mein dekhein.`
              : 'Client ne poori payment kar di hai. Apni kamai app mein dekhein.',
        },
        ur: {
          title: 'ادائیگی موصول ہو گئی',
          body:
            params.received != null
              ? `کلائنٹ نے پورے ${params.received} روپے دے دیے ہیں۔ اپنی کمائی ایپ میں دیکھیں۔`
              : 'کلائنٹ نے پوری ادائیگی کر دی ہے۔ اپنی کمائی ایپ میں دیکھیں۔',
        },
      });
    case NOTIFICATION_KEYS.PAYMENT_SHORT:
      return pick(locale, {
        en: {
          title: 'Short payment recorded',
          body:
            params.received != null && params.shortfall != null
              ? `Rs ${params.received} was received; Rs ${params.shortfall} is still due. Open the app for details.`
              : 'The client paid less than the agreed total. Open the app for details.',
        },
        ur_Latn: {
          title: 'Kam payment record hui hai',
          body:
            params.received != null && params.shortfall != null
              ? `Rs ${params.received} mile; Rs ${params.shortfall} abhi baqi hain. Tafseel app mein dekhein.`
              : 'Client ne tay shuda raqam se kam diya hai. Tafseel app mein dekhein.',
        },
        ur: {
          title: 'کم ادائیگی درج ہوئی ہے',
          body:
            params.received != null && params.shortfall != null
              ? `${params.received} روپے ملے؛ ${params.shortfall} روپے ابھی باقی ہیں۔ تفصیل ایپ میں دیکھیں۔`
              : 'کلائنٹ نے طے شدہ رقم سے کم ادائیگی کی ہے۔ تفصیل ایپ میں دیکھیں۔',
        },
      });
    case NOTIFICATION_KEYS.WORKER_AUTO_OFFLINE:
    case NOTIFICATION_KEYS.WORKER_FORCED_OFFLINE:
      return pick(locale, {
        en: {
          title: 'You are offline',
          body: 'Your availability is now offline. Go online again to receive new jobs.',
        },
        ur_Latn: {
          title: 'Aap offline ho gaye hain',
          body: 'Aapki availability offline ho gayi hai. Naye kaam ke liye dobara online hon.',
        },
        ur: {
          title: 'آپ آف لائن ہو گئے ہیں',
          body: 'آپ کی دستیابی آف لائن ہو گئی ہے۔ نئے کام کے لیے دوبارہ آن لائن ہوں۔',
        },
      });
    case NOTIFICATION_KEYS.WORKER_ONBOARDING_APPROVED:
    case NOTIFICATION_KEYS.WORKER_VERIFIED:
      return pick(locale, {
        en: {
          title: 'Profile approved',
          body: 'Your profile has been approved. Open the app to get started.',
        },
        ur_Latn: {
          title: 'Aapki profile approve ho gayi hai',
          body: 'Aapki profile approve ho gayi hai. Shuru karne ke liye app kholen.',
        },
        ur: {
          title: 'آپ کی پروفائل منظور ہو گئی ہے',
          body: 'آپ کی پروفائل منظور ہو گئی ہے۔ شروع کرنے کے لیے ایپ کھولیں۔',
        },
      });
    case NOTIFICATION_KEYS.WORKER_ONBOARDING_CHANGES_REQUIRED:
      return pick(locale, {
        en: {
          title: 'Profile changes required',
          body: reason
            ? `Admin requested profile changes. Reason: ${reason}`
            : 'Admin requested changes to your profile. Open it for details.',
        },
        ur_Latn: {
          title: 'Profile mein tabdeeli darkaar hai',
          body: reason
            ? `Admin ne profile mein tabdeeli mangi hai. Wajah: ${reason}`
            : 'Admin ne profile mein tabdeeli mangi hai. Tafseel app mein dekhein.',
        },
        ur: {
          title: 'پروفائل میں تبدیلی درکار ہے',
          body: reason
            ? `ایڈمن نے پروفائل میں تبدیلی مانگی ہے۔ وجہ: ${reason}`
            : 'ایڈمن نے پروفائل میں تبدیلی مانگی ہے۔ تفصیل ایپ میں دیکھیں۔',
        },
      });
    case NOTIFICATION_KEYS.STANDARD_JOB_LISTED:
    case NOTIFICATION_KEYS.INSPECTION_JOB_AVAILABLE:
    case NOTIFICATION_KEYS.BIDDING_JOB_AVAILABLE:
    case NOTIFICATION_KEYS.FIND_OTHER_USTAAD_AVAILABLE:
      return pick(locale, {
        en: {
          title: 'New job near you',
          body: 'Open New Jobs to view the details.',
        },
        ur_Latn: {
          title: 'Naya kaam aapke qareeb hai',
          body: 'Tafseel dekhne ke liye New Jobs kholen.',
        },
        ur: {
          title: 'نیا کام آپ کے قریب ہے',
          body: 'تفصیل دیکھنے کے لیے نئے کام کھولیں۔',
        },
      });
    case NOTIFICATION_KEYS.BID_RECEIVED:
      return {
        title: 'New offer received',
        body:
          params.workerName && params.amount
            ? `${params.workerName} sent you an offer for PKR ${params.amount}`
            : 'A worker sent you an offer. Tap to view.',
      };
    case NOTIFICATION_KEYS.BOOKING_STATUS_EN_ROUTE:
      return {
        title: 'Worker On the Way',
        body: 'Your worker is on the way to your location.',
      };
    case NOTIFICATION_KEYS.BOOKING_STATUS_IN_PROGRESS:
      return {
        title: 'Job Started',
        body: 'Your worker has started working on your request.',
      };
    case NOTIFICATION_KEYS.BOOKING_CANCELLED_BY_WORKER:
      return {
        title: 'Job Cancelled',
        body: 'The worker has cancelled the job.',
      };
    default:
      return { title: 'EasyRepair', body: 'You have a new notification.' };
  }
}
