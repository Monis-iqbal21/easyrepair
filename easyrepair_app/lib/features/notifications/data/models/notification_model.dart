import '../../domain/entities/notification_entity.dart';

class NotificationModel {
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

  const NotificationModel({
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

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      isRead: json['isRead'] as bool? ?? false,
      readAt: json['readAt'] != null
          ? DateTime.tryParse(json['readAt'] as String)
          : null,
      eventKey: json['eventKey'] as String?,
      bookingId: json['bookingId'] as String?,
      route: json['route'] as String?,
      payload: json['payload'] as Map<String, dynamic>?,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  NotificationEntity toEntity() => NotificationEntity(
        id: id,
        title: title,
        body: body,
        isRead: isRead,
        readAt: readAt,
        eventKey: eventKey,
        bookingId: bookingId,
        route: route,
        payload: payload,
        createdAt: createdAt,
      );
}
