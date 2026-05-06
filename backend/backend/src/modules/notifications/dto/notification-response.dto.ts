export class NotificationResponseDto {
  id!: string;
  title!: string;
  body!: string;
  isRead!: boolean;
  readAt!: string | null;
  eventKey!: string | null;
  bookingId!: string | null;
  route!: string | null;
  payload!: Record<string, unknown> | null;
  createdAt!: string;
}
