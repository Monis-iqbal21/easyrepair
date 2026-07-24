import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/failures.dart';
import '../../../chat/presentation/providers/chat_providers.dart';

/// Opens (or creates) the chat conversation tied to [bookingId] and
/// navigates the client into it. Mirrors openWorkerChatForBooking on the
/// worker side — same idempotent get-or-create endpoint.
///
/// NOTE: this hits `POST /chat/conversations/for-booking`, which is
/// WORKER-role-only on the backend — calling it from a CLIENT context always
/// 403s ("Forbidden resource"), regardless of booking status. Client screens
/// should use [openClientChatWithWorker] instead, which hits the correct
/// CLIENT-facing endpoint. Kept here only for any existing worker-side reuse.
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

/// Opens (or creates) the chat conversation between the current client and
/// [workerProfileId], and navigates the client into it. Uses the CLIENT-role
/// `POST /chat/conversations` endpoint, which has no booking-status
/// restriction — safe to call both before a worker is assigned (e.g. picking
/// an Ustaad in the inspection flow) and after a job is completed.
Future<void> openClientChatWithWorker(
  BuildContext context,
  WidgetRef ref,
  String workerProfileId,
) async {
  try {
    final conversation = await ref
        .read(getOrCreateConversationProvider.notifier)
        .getOrCreate(workerProfileId);
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
