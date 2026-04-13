import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

import '../config/app_config.dart';

/// Singleton Socket.IO client for the /chat namespace.
///
/// Lifecycle (managed by app.dart via authStateProvider listener):
///   connect(token) — called once after a successful login
///   disconnect()   — called on logout or token expiry
///
/// Consumers (Riverpod providers) subscribe to the three broadcast streams.
/// The socket reconnects automatically up to 5 times with a 1-second delay.
class ChatSocketService {
  ChatSocketService._();
  static final ChatSocketService instance = ChatSocketService._();

  IO.Socket? _socket;

  // ── Broadcast streams (providers subscribe via ref.onDispose-guarded subs) ─

  final StreamController<Map<String, dynamic>> _newMessageCtrl =
      StreamController<Map<String, dynamic>>.broadcast();

  final StreamController<Map<String, dynamic>> _conversationUpdatedCtrl =
      StreamController<Map<String, dynamic>>.broadcast();

  final StreamController<Map<String, dynamic>> _messageSeenCtrl =
      StreamController<Map<String, dynamic>>.broadcast();

  final StreamController<Map<String, dynamic>> _messageEditedCtrl =
      StreamController<Map<String, dynamic>>.broadcast();

  final StreamController<Map<String, dynamic>> _messageDeletedCtrl =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get onNewMessage => _newMessageCtrl.stream;
  Stream<Map<String, dynamic>> get onConversationUpdated =>
      _conversationUpdatedCtrl.stream;
  Stream<Map<String, dynamic>> get onMessageSeen => _messageSeenCtrl.stream;
  Stream<Map<String, dynamic>> get onMessageEdited => _messageEditedCtrl.stream;
  Stream<Map<String, dynamic>> get onMessageDeleted =>
      _messageDeletedCtrl.stream;

  bool get isConnected => _socket?.connected ?? false;

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  void connect(String token) {
    if (_socket != null && _socket!.connected) return;

    // Dispose any previous (disconnected) socket before creating a new one.
    _socket?.dispose();

    _socket = IO.io(
      '${AppConfig.wsUrl}/chat',
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': token})
          .enableReconnection()
          .setReconnectionAttempts(5)
          .setReconnectionDelay(1000)
          .disableAutoConnect()
          .build(),
    );

    _socket!
      ..on('connect', (_) => debugPrint('[ChatSocket] connected'))
      ..on('disconnect', (reason) =>
          debugPrint('[ChatSocket] disconnected: $reason'))
      ..on('connect_error', (e) => debugPrint('[ChatSocket] error: $e'))
      ..on('new_message', (data) {
        if (data is Map) {
          _newMessageCtrl.add(Map<String, dynamic>.from(data));
        }
      })
      ..on('conversation_updated', (data) {
        if (data is Map) {
          _conversationUpdatedCtrl.add(Map<String, dynamic>.from(data));
        }
      })
      ..on('message_seen', (data) {
        if (data is Map) {
          _messageSeenCtrl.add(Map<String, dynamic>.from(data));
        }
      })
      ..on('message_edited', (data) {
        if (data is Map) {
          _messageEditedCtrl.add(Map<String, dynamic>.from(data));
        }
      })
      ..on('message_deleted', (data) {
        if (data is Map) {
          _messageDeletedCtrl.add(Map<String, dynamic>.from(data));
        }
      });

    _socket!.connect();
  }

  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
  }

  // ── Emit helpers ───────────────────────────────────────────────────────────

  /// Tell the server we are viewing this conversation so it adds us to the
  /// socket room and we receive new_message / message_seen events for it.
  void joinConversation(String conversationId) {
    _socket?.emit('join_conversation', {'conversationId': conversationId});
  }

  /// Tell the server we left the conversation screen.
  void leaveConversation(String conversationId) {
    _socket?.emit('leave_conversation', {'conversationId': conversationId});
  }

  /// Mark [messageId] as seen.  Server validates ownership + idempotency.
  void markSeen(String conversationId, String messageId) {
    _socket?.emit('mark_seen', {
      'conversationId': conversationId,
      'messageId': messageId,
    });
  }
}
