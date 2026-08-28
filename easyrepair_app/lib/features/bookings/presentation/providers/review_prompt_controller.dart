import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/booking_entity.dart';
import '../widgets/review_modal.dart';
import '../widgets/cash_payment_confirmation_card.dart';
import 'booking_providers.dart';

/// Completed bookings this client still owes a review for — backend truth.
/// The controller never treats an in-memory notification callback as proof
/// that a review is (or is not) pending.
final pendingReviewsProvider = FutureProvider.autoDispose<List<BookingEntity>>((
  ref,
) async {
  final result = await ref.read(bookingRepositoryProvider).getPendingReviews();
  return result.fold((f) => throw f, (bookings) => bookings);
});

/// THE single owner of every review modal in the app.
///
/// No screen opens [ReviewModal] directly: the foreground `booking.completed`
/// handler, the notification-tap path, the app-resume sweep and the
/// Find-Other-Ustaad transition all go through here, so two modals can never
/// stack for the same booking (or at all).
///
/// Guard lifetime, deliberately:
///   * [_activeBookingId] is held for as long as a modal is on screen;
///   * a FAILED submission keeps the modal open and KEEPS the guard;
///   * the guard is released only when the modal actually closes;
///   * a booking is forgotten permanently only once the backend stops
///     returning it from `/bookings/pending-reviews` — never merely because
///     it was prompted once.
class ReviewPromptController {
  ReviewPromptController(this._ref);

  final Ref _ref;

  /// The booking whose modal is currently on screen (or reserved). Exactly
  /// one at a time.
  String? _activeBookingId;

  /// Mandatory prompts (Find Other Ustaad) outrank queued ordinary ones.
  bool _activeIsMandatory = false;

  /// FIFO of bookings waiting for their turn. Drained one at a time.
  final List<String> _queue = <String>[];

  /// Bookings the client dismissed this session. Suppresses an immediate
  /// re-open loop WITHOUT marking them reviewed — cleared on app resume so a
  /// postponed or failed review is offered again later.
  final Set<String> _deferredThisSession = <String>{};

  bool _draining = false;

  // ── Test/diagnostic surface ───────────────────────────────────────────────
  String? get activeBookingId => _activeBookingId;
  bool get isShowing => _activeBookingId != null;

  /// True while the active prompt is the non-bypassable one.
  bool get isMandatoryActive => _activeIsMandatory;
  List<String> get queuedBookingIds => List.unmodifiable(_queue);
  bool isDeferred(String bookingId) => _deferredThisSession.contains(bookingId);

  // ── Mandatory (Find Other Ustaad) ─────────────────────────────────────────

  /// Claims the guard for [bookingId] SYNCHRONOUSLY, before the network call
  /// that will complete the booking.
  ///
  /// The completion push can arrive before that call's HTTP response, so
  /// reserving afterwards would still let the ordinary foreground modal open
  /// first. Returns false if something else already holds the guard.
  bool reserveMandatory(String bookingId) {
    if (_activeBookingId != null && _activeBookingId != bookingId) return false;
    _activeBookingId = bookingId;
    _activeIsMandatory = true;
    _queue.remove(bookingId);
    _deferredThisSession.remove(bookingId);
    return true;
  }

  /// Undoes a [reserveMandatory] when the request it guarded failed.
  void releaseReservation(String bookingId) {
    if (_activeBookingId != bookingId) return;
    _activeBookingId = null;
    _activeIsMandatory = false;
  }

  /// Shows the non-bypassable review for [bookingId].
  ///
  /// Resolves `true` only after a confirmed successful submission. A failed
  /// submission leaves the modal open and this Future PENDING — it never
  /// resolves false while the modal is still visible. It resolves `false`
  /// only on a genuine abort after the modal has actually closed.
  Future<bool> showMandatory(
    BuildContext context,
    BookingEntity booking,
  ) async {
    reserveMandatory(booking.id);
    final completer = Completer<bool>();

    // Awaited separately from the completer: the dialog's own future
    // completing means the modal actually closed, which is the ONLY thing
    // that may release the guard.
    unawaited(
      showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => ReviewModal(booking: booking, mandatory: true),
      ).then((submitted) {
        _activeBookingId = null;
        _activeIsMandatory = false;
        if (submitted == true) {
          _deferredThisSession.remove(booking.id);
          if (!completer.isCompleted) completer.complete(true);
        } else {
          // Mandatory modals cannot be dismissed by the user, so reaching
          // here means the host was torn down — a genuine abort.
          if (!completer.isCompleted) completer.complete(false);
        }
        if (context.mounted) unawaited(_drain(context));
      }),
    );

    return completer.future;
  }

  // ── Ordinary prompts ──────────────────────────────────────────────────────

  /// Queue [bookingId] behind anything already waiting.
  void enqueue(BuildContext context, String bookingId) =>
      _enqueue(context, bookingId, front: false);

  /// Notification tap: the booking the client explicitly acted on jumps to the
  /// FRONT, ahead of unrelated older pending reviews.
  void enqueueFront(BuildContext context, String bookingId) =>
      _enqueue(context, bookingId, front: true);

  void _enqueue(BuildContext context, String bookingId, {required bool front}) {
    // Already on screen (or reserved) — collapse into it rather than stacking.
    if (_activeBookingId == bookingId) return;
    if (_deferredThisSession.contains(bookingId) && !front) return;
    // An explicit tap overrides an earlier dismissal.
    if (front) _deferredThisSession.remove(bookingId);

    _queue.remove(bookingId);
    if (front) {
      _queue.insert(0, bookingId);
    } else {
      _queue.add(bookingId);
    }
    unawaited(_drain(context));
  }

  /// App resumed: a postponed or failed review becomes offerable again.
  void clearSessionDeferrals() => _deferredThisSession.clear();

  /// Re-fetch backend truth and queue anything still outstanding.
  Future<void> refreshAndPrompt(BuildContext context) async {
    try {
      final pending = await _ref.refresh(pendingReviewsProvider.future);
      if (!context.mounted) return;
      for (final booking in pending) {
        _enqueue(context, booking.id, front: false);
      }
    } catch (_) {
      // A failed fetch must never surface as an error to the client; the
      // next resume will try again.
    }
  }

  // ── Queue draining ────────────────────────────────────────────────────────

  Future<void> _drain(BuildContext context) async {
    if (_draining || _activeBookingId != null) return;
    if (_queue.isEmpty) return;
    _draining = true;
    try {
      while (_queue.isNotEmpty && _activeBookingId == null) {
        // PEEK, don't pop: resolving is async, and a notification tap during
        // that window must be able to jump ahead of this one.
        final bookingId = _queue.first;
        if (!context.mounted) return;

        final booking = await _resolvePending(bookingId);

        // A front-jump landed while we were resolving — restart on the new
        // head so the tapped booking is genuinely shown first.
        if (_queue.isEmpty || _queue.first != bookingId) continue;
        _queue.removeAt(0);

        // Gone from the backend's pending list ⇒ the review demonstrably
        // exists ⇒ forget it permanently. This is the ONLY way a booking
        // leaves the queue for good.
        if (booking == null) continue;
        if (!context.mounted) return;

        // A completion cash prompt owns the modal lane until it actually
        // closes. Wait without polling so Payment and Review can never be
        // presented on top of one another; this does not change review
        // eligibility or submission rules.
        final cashPrompt = _ref.read(cashPaymentPromptControllerProvider);
        if (cashPrompt.isShowing) {
          _queue.insert(0, bookingId);
          await cashPrompt.whenIdle;
          continue;
        }

        _activeBookingId = bookingId;
        _activeIsMandatory = false;
        final submitted = await showDialog<bool>(
          context: context,
          barrierDismissible: true,
          builder: (_) => ReviewModal(booking: booking),
        );
        _activeBookingId = null;

        if (submitted != true) {
          // Dismissed or failed — still pending, just not re-offered until
          // the next resume, so it cannot loop straight back open.
          _deferredThisSession.add(bookingId);
        }
      }
    } finally {
      _draining = false;
    }
  }

  /// The booking, but only while the backend still lists it as unreviewed.
  ///
  /// A cache miss is NOT proof the review exists. [pendingReviewsProvider] is
  /// kept alive by this controller, so its first result — typically an empty
  /// list fetched at launch, before anything had completed — would otherwise
  /// be reused forever. Every booking queued afterwards looked "already
  /// reviewed" and was dropped permanently, which is why the completion
  /// popup, the notification tap and the Review Worker button all appeared to
  /// do nothing.
  ///
  /// So: trust a hit, but re-read backend truth once before concluding a miss
  /// means reviewed. Refreshing only on the miss path keeps the common case
  /// (draining several already-fetched bookings) to a single request.
  Future<BookingEntity?> _resolvePending(String bookingId) async {
    final cached = await _readPending(refresh: false);
    final hit = _findById(cached, bookingId);
    if (hit != null) return hit;

    final fresh = await _readPending(refresh: true);
    return _findById(fresh, bookingId);
  }

  Future<List<BookingEntity>> _readPending({required bool refresh}) async {
    try {
      return refresh
          ? await _ref.refresh(pendingReviewsProvider.future)
          : await _ref.read(pendingReviewsProvider.future);
    } catch (_) {
      // A failed fetch must never surface as an error to the client, and must
      // never be read as "nothing pending" — the caller retries on the next
      // resume.
      return const [];
    }
  }

  BookingEntity? _findById(List<BookingEntity> bookings, String bookingId) {
    for (final b in bookings) {
      if (b.id == bookingId) return b;
    }
    return null;
  }
}

final reviewPromptControllerProvider = Provider<ReviewPromptController>(
  (ref) => ReviewPromptController(ref),
);
