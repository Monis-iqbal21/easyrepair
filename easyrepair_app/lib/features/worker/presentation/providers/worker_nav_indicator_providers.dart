import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../chat/presentation/providers/chat_providers.dart';
import 'worker_job_providers.dart';
import 'worker_providers.dart';

/// The Ustaad bottom-navigation indicators, in one place.
///
/// Every provider here is *derived* — none of them fetches, polls or holds
/// state of its own. They read the same providers the screens behind each tab
/// already read, so an indicator can never disagree with the screen it points
/// at, and it refreshes through exactly the mechanisms those providers already
/// have (socket pushes, FCM invalidation, app-resume invalidation in
/// `app.dart`). Nothing new is scheduled.

// ── Chat tab ─────────────────────────────────────────────────────────────────

/// Number of CONVERSATIONS that have at least one unread message — not the
/// number of unread messages.
///
/// Ten unread messages from one client is one conversation, so the badge reads
/// "one person is waiting on me", which is the decision an Ustaad actually
/// makes from a bottom bar. `ConversationEntity.unreadCount` is the backend's
/// own per-conversation counter (it survives a restart and is cleared by
/// opening the thread), so this invents no read/seen state: it only asks each
/// conversation whether that persisted counter is above zero.
///
/// While the list is loading or failed this is 0 — a badge is an alert, and an
/// alert must never be guessed at.
final workerUnreadConversationCountProvider = Provider<int>((ref) {
  final conversations = ref.watch(chatConversationsProvider).valueOrNull;
  if (conversations == null) return 0;
  return conversations.where((c) => c.unreadCount > 0).length;
});

// ── My Jobs tab ──────────────────────────────────────────────────────────────

/// True while this Ustaad has a job in hand right now.
///
/// Deliberately no second opinion on what "ongoing" means: it is exactly
/// `WorkerProfileEntity.ongoingJob`, the server-decided field the Home
/// "Today" section already uses to choose between the active-job card and the
/// no-job card (`worker_home_page.dart`). If Home shows an active job, the dot
/// is lit; if Home shows "no job", it is not.
final workerHasOngoingJobProvider = Provider<bool>((ref) {
  final profile = ref.watch(workerProfileProvider).valueOrNull;
  return profile?.ongoingJob != null;
});

// ── Naye Kaam tab ────────────────────────────────────────────────────────────

/// How long a New Job stays "new". Jobs older than this never count, however
/// long ago the Ustaad last looked — a badge that can only grow is noise.
const newJobsUnreadWindow = Duration(hours: 24);

/// THE count of unread New Jobs. The Naye Kaam tab badge and the Home
/// "Nayi Shikayat" card both read this provider and nothing else — there is
/// no second place where this number is worked out.
///
/// A job counts when BOTH are true:
///
///   * it is in [newJobsUnfilteredProvider] — i.e. the backend's own
///     `GET /workers/jobs/new` matching decided this Ustaad may take it. The
///     eligibility rules are not restated here, or anywhere on the device;
///     the badge counts rows the server already qualified. The screen's
///     all/myBids/notBidYet chip is deliberately excluded (see that
///     provider's doc) so tapping a chip cannot move the badge;
///   * it arrived inside [newJobsUnreadWindow] AND after
///     `WorkerProfileEntity.newJobsSeenAt`, the server-persisted instant the
///     Ustaad last opened Naye Kaam. Persisted per Worker, so it survives a
///     reinstall and reads the same on a second device.
///
/// A null `newJobsSeenAt` means the screen has never been opened, so the
/// window alone decides — the honest reading of "never looked", and what
/// every existing Ustaad gets on the day the column ships.
///
/// Both sides refresh through mechanisms that already exist: the jobs list
/// via its own fetch and `app.dart`'s FCM/socket/resume invalidation of
/// `newJobsProvider`, the marker via the same invalidation of
/// `workerProfileProvider`. Nothing here schedules anything.
final workerNewJobsUnreadCountProvider = Provider<int>((ref) {
  // Watched for its lifecycle, not its value: this is what makes the feed
  // load for an Ustaad sitting on Home or Chat who has not opened Naye Kaam
  // yet. It adds no polling — `newJobsProvider` is not autoDispose, so its
  // existing 30 s timer already runs for the rest of the session once the
  // feed has been touched at all; this only moves when that starts.
  ref.watch(newJobsProvider);
  // The value comes from the UNFILTERED list, so the screen's filter chip
  // cannot move the badge.
  final jobs = ref.watch(newJobsUnfilteredProvider);
  if (jobs.isEmpty) return 0;

  final seenAt = ref
      .watch(workerProfileProvider)
      .valueOrNull
      ?.newJobsSeenAt
      ?.toUtc();
  final windowStart = DateTime.now().toUtc().subtract(newJobsUnreadWindow);
  // Whichever cutoff is later wins: the 24h window caps how far back "new"
  // can reach, and the seen marker caps it further once the Ustaad has looked.
  final cutoff = (seenAt != null && seenAt.isAfter(windowStart))
      ? seenAt
      : windowStart;

  return jobs.where((j) => j.createdAt.toUtc().isAfter(cutoff)).length;
});
