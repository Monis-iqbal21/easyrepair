export default () => ({
  port: parseInt(process.env.PORT || '3000', 10),
  database: {
    url: process.env.DATABASE_URL,
  },
  redis: {
    url: process.env.REDIS_URL,
  },
  jwt: {
    secret: process.env.JWT_SECRET,
    accessExpires: process.env.JWT_ACCESS_EXPIRES || '15m',
    refreshExpires: process.env.JWT_REFRESH_EXPIRES || '30d',
  },
  firebase: {
    projectId: process.env.FIREBASE_PROJECT_ID,
    privateKey: process.env.FIREBASE_PRIVATE_KEY?.replace(/\\n/g, '\n'),
    clientEmail: process.env.FIREBASE_CLIENT_EMAIL,
  },
  sms: {
    apiKey: process.env.SMS_API_KEY,
    apiUrl: process.env.SMS_API_URL,
    sender: process.env.SMS_SENDER || 'Default',
  },
  storage: {
    bucket: process.env.R2_BUCKET,
    accountId: process.env.R2_ACCOUNT_ID,
    accessKey: process.env.R2_ACCESS_KEY_ID,
    secretKey: process.env.R2_SECRET_ACCESS_KEY,
    publicUrl: (process.env.R2_PUBLIC_URL ?? '').replace(/\/$/, ''),
    endpoint: process.env.R2_ENDPOINT, // optional override; derived from accountId if omitted
  },
  business: {
    timezone: process.env.BUSINESS_TIMEZONE || 'Asia/Karachi',
  },
  usePostgis: process.env.USE_POSTGIS === 'true',
  support: {
    /**
     * Reserved phone identifying the single "HandyGo Support" system user.
     * This account is provisioned on demand and can never be logged into —
     * see SupportUserService.
     */
    userPhone: process.env.SUPPORT_USER_PHONE || '+920000000000',
    displayName: process.env.SUPPORT_DISPLAY_NAME || 'HandyGo Support',
  },
  matching: {
    /**
     * Radius (km) from a booking's pinned location within which an eligible
     * Ustaad may be notified about it and see it in New Jobs. Single source
     * of truth for every lane — see job-eligibility.util.ts.
     */
    radiusKm: parseFloat(process.env.MATCH_RADIUS_KM || '7'),
    /** Per-worker cooldown (seconds) for location-driven re-matching. */
    locationCooldownSeconds: parseInt(
      process.env.MATCH_LOCATION_COOLDOWN_SECONDS || '60',
      10,
    ),
    /**
     * How many recipients (or jobs) the broadcast fan-out re-reads and pushes
     * per batch. Purely a round-trip/latency knob: every batch still re-reads
     * BOTH sides from the database immediately before pushing, so the
     * pre-push eligibility recheck is unaffected by this value.
     */
    fanOutChunkSize: parseInt(process.env.MATCH_FANOUT_CHUNK_SIZE || '50', 10),
    /**
     * Runaway guard on the nearby-worker candidate query (see
     * DEFAULT_NEARBY_FETCH_LIMIT in bookings.repository.ts). The query is
     * ordered nearest-first, so this can only ever drop workers farther away
     * than those kept, in a pool far larger than the 4-worker target or the
     * client UI needs.
     */
    nearbyWorkerFetchLimit: parseInt(
      process.env.MATCH_NEARBY_FETCH_LIMIT || '200',
      10,
    ),
  },
  presence: {
    /**
     * How many hours a Worker's ONLINE status may go without a genuine
     * app-activity signal (see touchWorkerPresence) before it is treated as
     * stale — excluded from new-job matching immediately, and force-flipped
     * to OFFLINE by the periodic cleanup job. Single source of truth — see
     * WORKER_PRESENCE_STALE_MS in job-eligibility.util.ts. Independent of,
     * and never a replacement for, GPS/location freshness.
     */
    workerOnlineStaleHours: parseFloat(
      process.env.WORKER_ONLINE_STALE_HOURS || '6',
    ),
  },
  discovery: {
    /**
     * How many hours an open job stays in New Jobs discovery (feed,
     * broadcast, late-discovery push) after creation, regardless of its
     * BookingStatus. Single source of truth — see JOB_DISCOVERY_WINDOW_MS in
     * job-eligibility.util.ts. Discovery filtering only, never deletion — a
     * worker's existing bid/history on an older job is unaffected.
     */
    jobDiscoveryWindowHours: parseFloat(
      process.env.JOB_DISCOVERY_WINDOW_HOURS || '48',
    ),
  },
  whatsapp: {
    token: process.env.WHATSAPP_TOKEN,
    phoneNumberId: process.env.WHATSAPP_PHONE_NUMBER_ID,
    apiVersion: process.env.WHATSAPP_API_VERSION || 'v20.0',
    otpTemplateName: process.env.WHATSAPP_OTP_TEMPLATE_NAME,
    otpTemplateLanguage: process.env.WHATSAPP_OTP_TEMPLATE_LANGUAGE || 'en_US',
    includeButtonCode: process.env.WHATSAPP_OTP_INCLUDE_BUTTON_CODE || 'false',
  },
  forgotPassword: {
    devOtp: process.env.FORGOT_PASSWORD_DEV_OTP,
  },
  otpAdmin: {
    /**
     * 32-byte AES-256-GCM key (64 hex chars, or base64) backing the Admin
     * OTP-reveal feature only — see otp-encryption.util.ts. Optional at boot
     * (like SMS_API_KEY/R2 creds): when unset, OTP request/verify continue
     * working exactly as before, the new OTP just isn't admin-revealable.
     */
    encryptionKey: process.env.OTP_ADMIN_ENCRYPTION_KEY,
  },
  adminReadonly: {
    /**
     * Machine credential for the GET-only /admin-readonly surface. Store only
     * the SHA-256 digest in deployment config; the raw key belongs in the
     * approved secret manager and is never committed or logged.
     */
    apiKeySha256: process.env.ADMIN_READONLY_API_KEY_SHA256,
    clientId: process.env.ADMIN_READONLY_CLIENT_ID || 'admin-readonly',
    scopes: process.env.ADMIN_READONLY_SCOPES || '',
    expiresAt: process.env.ADMIN_READONLY_EXPIRES_AT,
    rateLimitPerMinute: parseInt(
      process.env.ADMIN_READONLY_RATE_LIMIT_PER_MINUTE || '120',
      10,
    ),
  },
});
