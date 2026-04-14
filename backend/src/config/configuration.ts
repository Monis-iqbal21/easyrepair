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
  },
  storage: {
    bucket: process.env.R2_BUCKET,
    accountId: process.env.R2_ACCOUNT_ID,
    accessKey: process.env.R2_ACCESS_KEY_ID,
    secretKey: process.env.R2_SECRET_ACCESS_KEY,
    publicUrl: (process.env.R2_PUBLIC_URL ?? '').replace(/\/$/, ''),
    endpoint: process.env.R2_ENDPOINT, // optional override; derived from accountId if omitted
  },
  platform: {
    feePercent: parseInt(process.env.PLATFORM_FEE_PERCENT || '10', 10),
  },
  usePostgis: process.env.USE_POSTGIS === 'true',
});
