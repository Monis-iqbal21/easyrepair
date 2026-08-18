export class ConversationParticipantDto {
  userId: string;
  firstName: string;
  lastName: string;
  avatarUrl: string | null;
  /** Populated only when the participant is a worker; null for clients. */
  rating: number | null;
  /**
   * The other participant's registered phone number — powers the chat
   * header's call button. Null for the HandyGo Support thread (no invented
   * support number is ever returned here).
   */
  phone: string | null;
}

export class ConversationResponseDto {
  id: string;
  clientUserId: string;
  workerUserId: string;
  createdByUserId: string;
  lastMessageAt: string | null;
  lastMessagePreview: string | null;
  createdAt: string;
  updatedAt: string;
  /** The other participant from the perspective of the caller */
  otherParticipant: ConversationParticipantDto;
  /** Messages sent by others in this conversation that the caller hasn't seen yet */
  unreadCount: number;
  /**
   * True for the user's single HandyGo Support thread. Derived from the
   * support system user being one of the participants — there is no schema
   * discriminator. The app pins this conversation to the top of the Chat tab
   * and renders the bundled HandyGo logo as its avatar.
   */
  isSupport?: boolean;
}
