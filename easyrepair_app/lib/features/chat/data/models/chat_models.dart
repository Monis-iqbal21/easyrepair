import '../../domain/entities/chat_entities.dart';

class ConversationParticipantModel {
  final String userId;
  final String firstName;
  final String lastName;
  final String? avatarUrl;
  final double? rating;
  final String? phone;

  const ConversationParticipantModel({
    required this.userId,
    required this.firstName,
    required this.lastName,
    this.avatarUrl,
    this.rating,
    this.phone,
  });

  factory ConversationParticipantModel.fromJson(Map<String, dynamic> json) {
    return ConversationParticipantModel(
      userId: json['userId'] as String,
      firstName: json['firstName'] as String? ?? '',
      lastName: json['lastName'] as String? ?? '',
      avatarUrl: json['avatarUrl'] as String?,
      rating: (json['rating'] as num?)?.toDouble(),
      phone: json['phone'] as String?,
    );
  }

  ConversationParticipantEntity toEntity() {
    return ConversationParticipantEntity(
      userId: userId,
      firstName: firstName,
      lastName: lastName,
      avatarUrl: avatarUrl,
      rating: rating,
      phone: phone,
    );
  }
}

class ConversationModel {
  final String id;
  final String clientUserId;
  final String workerUserId;
  final String createdByUserId;
  final String? lastMessageAt;
  final String? lastMessagePreview;
  final String createdAt;
  final String updatedAt;
  final ConversationParticipantModel otherParticipant;
  final int unreadCount;
  final bool isSupport;

  const ConversationModel({
    required this.id,
    required this.clientUserId,
    required this.workerUserId,
    required this.createdByUserId,
    this.lastMessageAt,
    this.lastMessagePreview,
    required this.createdAt,
    required this.updatedAt,
    required this.otherParticipant,
    this.unreadCount = 0,
    this.isSupport = false,
  });

  factory ConversationModel.fromJson(Map<String, dynamic> json) {
    return ConversationModel(
      id: json['id'] as String,
      clientUserId: json['clientUserId'] as String,
      workerUserId: json['workerUserId'] as String,
      createdByUserId: json['createdByUserId'] as String,
      lastMessageAt: json['lastMessageAt'] as String?,
      lastMessagePreview: json['lastMessagePreview'] as String?,
      createdAt: json['createdAt'] as String,
      updatedAt: json['updatedAt'] as String,
      otherParticipant: ConversationParticipantModel.fromJson(
        json['otherParticipant'] as Map<String, dynamic>,
      ),
      unreadCount: (json['unreadCount'] as num?)?.toInt() ?? 0,
      // Absent on an older backend build — degrade to an ordinary chat rather
      // than throwing.
      isSupport: json['isSupport'] == true,
    );
  }

  ConversationEntity toEntity() {
    return ConversationEntity(
      id: id,
      clientUserId: clientUserId,
      workerUserId: workerUserId,
      createdByUserId: createdByUserId,
      lastMessageAt: lastMessageAt,
      lastMessagePreview: lastMessagePreview,
      createdAt: createdAt,
      updatedAt: updatedAt,
      otherParticipant: otherParticipant.toEntity(),
      unreadCount: unreadCount,
      isSupport: isSupport,
    );
  }
}

ChatMessageType _parseMessageType(String raw) {
  switch (raw.toUpperCase()) {
    case 'IMAGE':
      return ChatMessageType.image;
    case 'VIDEO':
      return ChatMessageType.video;
    case 'VOICE':
      return ChatMessageType.voice;
    case 'LOCATION':
      return ChatMessageType.location;
    case 'SYSTEM':
      return ChatMessageType.system;
    default:
      return ChatMessageType.text;
  }
}

class MessageModel {
  final String id;
  final String conversationId;
  final String senderUserId;
  final String senderRole;
  final ChatMessageType type;
  final String? text;
  final String? mediaUrl;
  final String? storageKey;
  final String? thumbnailUrl;
  final String? mimeType;
  final String? fileName;
  final int? sizeBytes;
  final double? durationSeconds;
  final double? latitude;
  final double? longitude;
  final String? bookingId;
  final String? replyToMessageId;
  final String? editedAt;
  final String? deletedAt;
  final String? seenAt;
  final String createdAt;
  final String updatedAt;

  const MessageModel({
    required this.id,
    required this.conversationId,
    required this.senderUserId,
    required this.senderRole,
    required this.type,
    this.text,
    this.mediaUrl,
    this.storageKey,
    this.thumbnailUrl,
    this.mimeType,
    this.fileName,
    this.sizeBytes,
    this.durationSeconds,
    this.latitude,
    this.longitude,
    this.bookingId,
    this.replyToMessageId,
    this.editedAt,
    this.deletedAt,
    this.seenAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    return MessageModel(
      id: json['id'] as String,
      conversationId: json['conversationId'] as String,
      senderUserId: json['senderUserId'] as String,
      senderRole: json['senderRole'] as String,
      type: _parseMessageType(json['type'] as String? ?? 'TEXT'),
      text: json['text'] as String?,
      mediaUrl: json['mediaUrl'] as String?,
      storageKey: json['storageKey'] as String?,
      thumbnailUrl: json['thumbnailUrl'] as String?,
      mimeType: json['mimeType'] as String?,
      fileName: json['fileName'] as String?,
      sizeBytes: (json['sizeBytes'] as num?)?.toInt(),
      durationSeconds: (json['durationSeconds'] as num?)?.toDouble(),
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      bookingId: json['bookingId'] as String?,
      replyToMessageId: json['replyToMessageId'] as String?,
      editedAt: json['editedAt'] as String?,
      deletedAt: json['deletedAt'] as String?,
      seenAt: json['seenAt'] as String?,
      createdAt: json['createdAt'] as String,
      updatedAt: json['updatedAt'] as String,
    );
  }

  MessageEntity toEntity() {
    return MessageEntity(
      id: id,
      conversationId: conversationId,
      senderUserId: senderUserId,
      senderRole: senderRole,
      type: type,
      text: text,
      mediaUrl: mediaUrl,
      storageKey: storageKey,
      thumbnailUrl: thumbnailUrl,
      mimeType: mimeType,
      fileName: fileName,
      sizeBytes: sizeBytes,
      durationSeconds: durationSeconds,
      latitude: latitude,
      longitude: longitude,
      bookingId: bookingId,
      replyToMessageId: replyToMessageId,
      editedAt: editedAt,
      deletedAt: deletedAt,
      seenAt: seenAt,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
