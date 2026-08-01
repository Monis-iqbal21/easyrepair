enum ChatMessageType { text, image, video, voice, location, system }

class ConversationParticipantEntity {
  final String userId;
  final String firstName;
  final String lastName;
  final String? avatarUrl;
  /// Non-null only when the participant is a worker.
  final double? rating;

  const ConversationParticipantEntity({
    required this.userId,
    required this.firstName,
    required this.lastName,
    this.avatarUrl,
    this.rating,
  });

  String get fullName => '$firstName $lastName'.trim();
  String get initials {
    final f = firstName.isNotEmpty ? firstName[0].toUpperCase() : '';
    final l = lastName.isNotEmpty ? lastName[0].toUpperCase() : '';
    return '$f$l';
  }
}

class ConversationEntity {
  final String id;
  final String clientUserId;
  final String workerUserId;
  final String createdByUserId;
  final String? lastMessageAt;
  final String? lastMessagePreview;
  final String createdAt;
  final String updatedAt;
  final ConversationParticipantEntity otherParticipant;
  final int unreadCount;

  /// True for the single permanent HandyGo Support thread. Decided by the
  /// backend — the app never infers it from the participant's name.
  final bool isSupport;

  const ConversationEntity({
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
}

class MessageEntity {
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

  const MessageEntity({
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

  bool get isDeleted => deletedAt != null;

  /// Return a copy with [seenAt] set.
  MessageEntity withSeenAt(String seenAt) => MessageEntity(
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

  /// Return a copy with [editedAt] and updated [text].
  MessageEntity withEdited(String editedAt, String newText) => MessageEntity(
        id: id,
        conversationId: conversationId,
        senderUserId: senderUserId,
        senderRole: senderRole,
        type: type,
        text: newText,
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
        seenAt: this.seenAt,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );

  /// Return a copy with [deletedAt] set (soft delete).
  MessageEntity withDeleted(String deletedAt) => MessageEntity(
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
