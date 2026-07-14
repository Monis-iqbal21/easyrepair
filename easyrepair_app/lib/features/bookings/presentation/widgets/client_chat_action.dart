import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/failures.dart';
import '../../../chat/presentation/providers/chat_providers.dart';

/// Opens (or creates) the chat conversation tied to [bookingId] and
/// navigates the client into it. Mirrors openWorkerChatForBooking on the
/// worker side — same idempotent get-or-create endpoint.
Future<void> openClientChatForBooking(
  BuildContext context,
  WidgetRef ref,
  String bookingId,
) async {
  try {
    final conversation = await ref
        .read(getOrCreateConversationForBookingProvider.notifier)
        .getOrCreate(bookingId);
    if (context.mounted) {
      context.push('/client/chat/${conversation.id}');
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
