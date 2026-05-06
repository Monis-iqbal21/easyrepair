export class ConversationParticipantDto {
  userId: string;
  firstName: string;
  lastName: string;
  avatarUrl: string | null;
  /** Populated only when the participant is a worker; null for clients. */
  rating: number | null;
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
}
