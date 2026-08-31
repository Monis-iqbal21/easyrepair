import { SetMetadata } from '@nestjs/common';

export const ADMIN_READONLY_SCOPES_KEY = 'adminReadonlyScopes';

export const ADMIN_READONLY_SCOPES = {
  STATS: 'admin.stats.read',
  BOOKINGS: 'admin.bookings.read',
  SETTLEMENTS: 'admin.settlements.read',
  WORKERS: 'admin.workers.read',
  CLIENTS: 'admin.clients.read',
  COMPLAINTS: 'admin.complaints.read',
} as const;

export type AdminReadonlyScope =
  (typeof ADMIN_READONLY_SCOPES)[keyof typeof ADMIN_READONLY_SCOPES];

export const AdminReadonlyScopes = (...scopes: AdminReadonlyScope[]) =>
  SetMetadata(ADMIN_READONLY_SCOPES_KEY, scopes);
