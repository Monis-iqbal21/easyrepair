import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/failures.dart';
import '../../../chat/presentation/providers/chat_providers.dart';

/// Opens (or creates) the chat conversation tied to [bookingId] and
/// navigates the worker into it. Used by the New Jobs card, job detail page,
/// and bid page so a worker can message the client before placing a bid.
///
/// Safe to call repeatedly — the backend endpoint is idempotent (get-or-create
/// keyed on the client/worker pair), so tapping "Chat" multiple times never
/// creates a duplicate conversation.
Future<void> openWorkerChatForBooking(
  BuildContext context,
  WidgetRef ref,
  String bookingId,
) async {
  try {
    final conversation = await ref
        .read(getOrCreateConversationForBookingProvider.notifier)
        .getOrCreate(bookingId);
    if (context.mounted) {
      context.push('/worker/chat/${conversation.id}');
    }
  } catch (e) {
    if (!context.mounted) return;
    final message = e is Failure ? e.message : 'Could not open chat.';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
