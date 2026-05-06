class NotificationEntity {
  final String id;
  final String title;
  final String body;
  final bool isRead;
  final DateTime? readAt;
  final String? eventKey;
  final String? bookingId;
  final String? route;
  final Map<String, dynamic>? payload;
  final DateTime createdAt;

  const NotificationEntity({
    required this.id,
    required this.title,
    required this.body,
    required this.isRead,
    this.readAt,
    this.eventKey,
    this.bookingId,
    this.route,
    this.payload,
    required this.createdAt,
  });
}
