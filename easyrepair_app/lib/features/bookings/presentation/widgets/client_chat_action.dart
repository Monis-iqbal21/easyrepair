import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../chat/presentation/providers/chat_providers.dart';
import '../../../../core/l10n/l10n_extensions.dart';
import '../../../../core/errors/failure_messages.dart';
import '../../../../core/theme/app_semantic_colors.dart';

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
    final message = failureMessage(
      context.l10n,
      e,
      fallback: context.l10n.chatOpenFailed,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: context.semanticColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}

/// Opens (or creates) the chat conversation between the current client and
/// [workerProfileId] for [bookingId], and navigates the client into it. Uses
/// the CLIENT-role `POST /chat/conversations` endpoint — safe to call both
/// before a worker is assigned (e.g. an eligible worker in the Standard/
/// Inspection selection list) and after a job is completed, as long as the
/// worker is actually eligible for/related to this booking (the backend
/// enforces this; bookingId is required so it can check).
Future<void> openClientChatWithWorker(
  BuildContext context,
  WidgetRef ref,
  String bookingId,
  String workerProfileId,
) async {
  try {
    final conversation = await ref
        .read(getOrCreateConversationProvider.notifier)
        .getOrCreate(bookingId, workerProfileId);
    if (context.mounted) {
      context.push('/client/chat/${conversation.id}');
    }
  } catch (e) {
    if (!context.mounted) return;
    final message = failureMessage(
      context.l10n,
      e,
      fallback: context.l10n.chatOpenFailed,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: context.semanticColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
