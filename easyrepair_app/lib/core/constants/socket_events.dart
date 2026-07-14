/// Socket.IO event name constants — /chat namespace (see ChatSocketService).
class SocketEvents {
  SocketEvents._();

  static const newMessage = 'new_message';
  static const conversationUpdated = 'conversation_updated';
  static const messageSeen = 'message_seen';
  static const messageEdited = 'message_edited';
  static const messageDeleted = 'message_deleted';
  static const joinConversation = 'join_conversation';
  static const leaveConversation = 'leave_conversation';
  static const markSeen = 'mark_seen';

  /// Global in-app top banner — booking lifecycle notifications
  /// (assigned, en route, arrived, cancelled, expired, relisted, etc).
  static const appBanner = 'app_banner';
}
