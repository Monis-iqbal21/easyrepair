export declare class ConversationParticipantDto {
    userId: string;
    firstName: string;
    lastName: string;
    avatarUrl: string | null;
    rating: number | null;
}
export declare class ConversationResponseDto {
    id: string;
    clientUserId: string;
    workerUserId: string;
    createdByUserId: string;
    lastMessageAt: string | null;
    lastMessagePreview: string | null;
    createdAt: string;
    updatedAt: string;
    otherParticipant: ConversationParticipantDto;
}
