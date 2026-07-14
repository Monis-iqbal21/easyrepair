import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

import '../config/app_config.dart';
import '../constants/socket_events.dart';

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

  // Conversation rooms the app currently has "open" (chat detail screen
  // mounted). Socket.io room membership does not survive a reconnect, so we
  // replay join_conversation for each of these every time the socket
  // (re)connects — otherwise a receiver whose app was briefly backgrounded
  // (or hit a transient network drop) stops getting new_message events for
  // an already-open chat until they leave and re-enter the screen.
  final Set<String> _activeConversationIds = {};

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

  // Global in-app top banner — server emits this to the user's personal
  // `user:{userId}` room (already joined for chat's own events) for any
  // booking lifecycle notification (assigned, en route, arrived, cancelled,
  // expired, etc). Not chat-specific, but reuses this same socket connection
  // rather than standing up a second one.
  final StreamController<Map<String, dynamic>> _appBannerCtrl =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get onNewMessage => _newMessageCtrl.stream;
  Stream<Map<String, dynamic>> get onConversationUpdated =>
      _conversationUpdatedCtrl.stream;
  Stream<Map<String, dynamic>> get onMessageSeen => _messageSeenCtrl.stream;
  Stream<Map<String, dynamic>> get onMessageEdited => _messageEditedCtrl.stream;
  Stream<Map<String, dynamic>> get onMessageDeleted =>
      _messageDeletedCtrl.stream;
  Stream<Map<String, dynamic>> get onAppBanner => _appBannerCtrl.stream;

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
      ..on('connect', (_) {
        debugPrint('[ChatSocket] connected');
        // Re-join every conversation room that was active before this
        // (re)connect — see _activeConversationIds doc comment above.
        for (final id in _activeConversationIds) {
          _socket?.emit(SocketEvents.joinConversation, {'conversationId': id});
        }
      })
      ..on('disconnect', (reason) =>
          debugPrint('[ChatSocket] disconnected: $reason'))
      ..on('connect_error', (e) => debugPrint('[ChatSocket] error: $e'))
      ..on(SocketEvents.newMessage, (data) {
        if (data is Map) {
          _newMessageCtrl.add(Map<String, dynamic>.from(data));
        }
      })
      ..on(SocketEvents.conversationUpdated, (data) {
        if (data is Map) {
          _conversationUpdatedCtrl.add(Map<String, dynamic>.from(data));
        }
      })
      ..on(SocketEvents.messageSeen, (data) {
        if (data is Map) {
          _messageSeenCtrl.add(Map<String, dynamic>.from(data));
        }
      })
      ..on(SocketEvents.messageEdited, (data) {
        if (data is Map) {
          _messageEditedCtrl.add(Map<String, dynamic>.from(data));
        }
      })
      ..on(SocketEvents.messageDeleted, (data) {
        if (data is Map) {
          _messageDeletedCtrl.add(Map<String, dynamic>.from(data));
        }
      })
      ..on(SocketEvents.appBanner, (data) {
        if (data is Map) {
          _appBannerCtrl.add(Map<String, dynamic>.from(data));
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
    _activeConversationIds.add(conversationId);
    _socket?.emit(SocketEvents.joinConversation, {'conversationId': conversationId});
  }

  /// Tell the server we left the conversation screen.
  void leaveConversation(String conversationId) {
    _activeConversationIds.remove(conversationId);
    _socket?.emit(SocketEvents.leaveConversation, {'conversationId': conversationId});
  }

  /// Mark [messageId] as seen.  Server validates ownership + idempotency.
  void markSeen(String conversationId, String messageId) {
    _socket?.emit(SocketEvents.markSeen, {
      'conversationId': conversationId,
      'messageId': messageId,
    });
  }
}
