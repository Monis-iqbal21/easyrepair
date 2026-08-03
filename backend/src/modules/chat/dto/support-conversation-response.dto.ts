import { Role } from '@prisma/client';

/**
 * One row of the admin Support Inbox.
 *
 * Deliberately minimal: name, avatar, and whether the requester is a Client
 * or an Ustaad. No booking history, no email, no address — an admin working
 * the inbox needs to know who they are talking to, not everything about them.
 */
export class SupportConversationDto {
  id: string;
  requesterUserId: string;
  /** CLIENT or WORKER — never ADMIN (support never messages itself). */
  requesterType: Role;
  requesterName: string;
  requesterAvatarUrl: string | null;
  lastMessageAt: string | null;
  lastMessagePreview: string | null;
  /** Messages from the requester that support has not yet read. */
  unreadCount: number;
  createdAt: string;
}

/** Slightly fuller detail, fetched only when an admin opens a thread. */
export class SupportRequesterInfoDto {
  userId: string;
  role: Role;
  name: string;
  avatarUrl: string | null;
  phone: string;
  memberSince: string;
}
