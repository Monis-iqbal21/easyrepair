import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:handygo_app/core/l10n/app_locale.dart';
import 'package:handygo_app/core/theme/app_theme.dart';
import 'package:handygo_app/features/auth/domain/entities/user_entity.dart';
import 'package:handygo_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:handygo_app/features/bookings/domain/entities/booking_entity.dart';
import 'package:handygo_app/features/bookings/domain/entities/inspection_report_entity.dart';
import 'package:handygo_app/features/bookings/presentation/pages/booking_detail_page.dart';
import 'package:handygo_app/features/bookings/presentation/providers/booking_providers.dart';
import 'package:handygo_app/features/bookings/presentation/widgets/detail/booking_action_section.dart';
import 'package:handygo_app/features/complaints/domain/entities/complaint_entity.dart';
import 'package:handygo_app/features/complaints/presentation/providers/complaint_providers.dart';

import '../../support/l10n_test_app.dart';

/// Booking Detail after the redesign: ONE shared shell for STANDARD,
/// INSPECTION and BIDDING, telling exactly the same status/price/payment
/// story as the Bookings tab, with no map and no client-facing control over
/// worker-owned lifecycle transitions.

const _bookingId = 'booking-1';

const _worker = AssignedWorkerEntity(
  id: 'worker-1',
  firstName: 'Ali',
  lastName: 'Khan',
  rating: 4.6,
  phone: '+923001234567',
);

const _inspector = AssignedWorkerEntity(
  id: 'worker-2',
  firstName: 'Bilal',
  lastName: 'Ahmed',
  rating: 4.2,
);

BookingEntity _booking({
  BookingLane lane = BookingLane.standard,
  BookingStatus status = BookingStatus.pending,
  String? title,
  String? description,
  AssignedWorkerEntity? worker,
  AssignedWorkerEntity? inspectingWorker,
  double? finalPrice,
  double? acceptedBidAmount,
  double? inspectionFeeSnapshot,
  List<BookingStandardServiceItemEntity> items = const [],
  List<BookingAttachmentEntity> attachments = const [],
  BookingReviewEntity? review,
  PaymentDisplayStatus payment = PaymentDisplayStatus.unpaid,
  double? receivedAmount,
  double? expectedAmount,
  double? remainingAmount,
  CancelledByRole? cancelledByRole,
  String? cancellationReason,
  String? lastWorkerCancellationReason,
  bool inspectionReportSubmitted = false,
  InspectionDecisionStatus? inspectionDecisionStatus,
  bool? inspectionFeePaid,
  String? sourceInspectionBookingId,
  String? attachedInspectionBookingId,
}) {
  return BookingEntity(
    id: _bookingId,
    referenceId: '#ER-123456',
    serviceCategory: 'AC Technician',
    serviceEmoji: '❄️',
    title: title,
    description: description,
    status: status,
    urgency: BookingUrgency.normal,
    timeSlot: TimeSlot.afternoon,
    scheduledDate: DateTime(2026, 8, 17),
    createdAt: DateTime(2026, 8, 1),
    address: 'House 12, Street 4',
    city: 'Lahore',
    lane: lane,
    assignedWorker: worker,
    inspectingWorker: inspectingWorker,
    finalPrice: finalPrice,
    acceptedBidAmount: acceptedBidAmount,
    inspectionFeeSnapshot: inspectionFeeSnapshot,
    standardServiceItems: items,
    attachments: attachments,
    review: review,
    paymentDisplayStatus: payment,
    receivedAmount: receivedAmount,
    expectedAmount: expectedAmount,
    remainingAmount: remainingAmount,
    cancelledByRole: cancelledByRole,
    cancellationReason: cancellationReason,
    lastWorkerCancellationReason: lastWorkerCancellationReason,
    inspectionReportSubmitted: inspectionReportSubmitted,
    inspectionDecisionStatus: inspectionDecisionStatus,
    inspectionFeePaid: inspectionFeePaid,
    sourceInspectionBookingId: sourceInspectionBookingId,
    attachedInspectionBookingId: attachedInspectionBookingId,
  );
}

const _acService = BookingStandardServiceItemEntity(
  id: 'i1',
  nameSnapshot: 'AC General Service',
  priceSnapshot: 2500,
);

const _installService = BookingStandardServiceItemEntity(
  id: 'i2',
  nameSnapshot: 'Split AC Installation',
  priceSnapshot: 3500,
);

/// Serves a fixed booking without touching the network, so the page renders
/// exactly the state under test.
class _StubDetailNotifier extends BookingDetailNotifier {
  _StubDetailNotifier(this.booking);

  final BookingEntity booking;

  @override
  Future<BookingEntity> build(String arg) async => booking;
}

class _StubComplaintNotifier extends BookingComplaintNotifier {
  _StubComplaintNotifier(this.complaint);

  final ComplaintEntity? complaint;

  @override
  Future<ComplaintEntity?> build(String bookingId) async => complaint;
}

ComplaintEntity _complaint({
  ComplaintStatus status = ComplaintStatus.open,
  bool humanRequested = false,
}) {
  return ComplaintEntity(
    id: 'complaint-1',
    bookingId: _bookingId,
    issueTypes: const [ComplaintIssueType.workQuality],
    status: status,
    source: 'APP_CUSTOMER',
    humanRequested: humanRequested,
    createdAt: DateTime(2026, 8, 20, 10, 30),
    updatedAt: DateTime(2026, 8, 20, 10, 30),
  );
}

final _report = InspectionReportEntity(
  id: 'report-1',
  bookingId: _bookingId,
  labourCost: 1500,
  partsNeeded: false,
  repairQuoteTotal: 1500,
  decisionStatus: InspectionDecisionStatus.pendingClientDecision,
  parts: const [],
  photos: const [],
  createdAt: DateTime(2026, 8, 18),
);

Future<GoRouter> _pumpDetail(
  WidgetTester tester,
  BookingEntity booking, {
  ComplaintEntity? complaint,
  InspectionReportEntity? report,
  bool isClient = true,
  AppLocale locale = AppLocale.english,
  ThemeData? theme,
  Size surface = const Size(390, 1800),
}) async {
  await tester.binding.setSurfaceSize(surface);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  // Tear down any previous tree first, so a test that pumps more than one
  // case gets a genuinely fresh ProviderScope rather than reusing the last
  // one's overrides.
  await tester.pumpWidget(const SizedBox.shrink());

  final router = GoRouter(
    initialLocation: '/client/booking/$_bookingId',
    routes: [
      GoRoute(
        path: '/client/booking/:id',
        builder: (_, state) =>
            BookingDetailPage(bookingId: state.pathParameters['id']!),
      ),
      GoRoute(path: '/client/jobs', builder: (_, _) => const SizedBox()),
      GoRoute(
        path: '/client/booking/:id/report',
        builder: (_, _) => const Scaffold(body: Text('report-page')),
      ),
      GoRoute(path: '/client/post-job', builder: (_, _) => const SizedBox()),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        bookingDetailProvider.overrideWith(() => _StubDetailNotifier(booking)),
        bookingComplaintProvider.overrideWith(
          () => _StubComplaintNotifier(complaint),
        ),
        inspectionReportProvider(_bookingId).overrideWith((_) async {
          if (report == null) throw Exception('no report');
          return report;
        }),
        authStateProvider.overrideWith(() => _StubAuthNotifier(isClient)),
      ],
      child: localizedRouterApp(
        router,
        locale: locale,
        theme: theme ?? AppTheme.lightTheme,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

class _StubAuthNotifier extends AuthStateNotifier {
  _StubAuthNotifier(this.isClient);

  final bool isClient;

  @override
  Future<UserEntity?> build() async => UserEntity(
    id: 'user-1',
    phone: '+923000000000',
    role: isClient ? 'CLIENT' : 'WORKER',
    firstName: 'Sara',
    lastName: 'Client',
  );
}

void main() {
  group('STANDARD lane', () {
    testWidgets('PENDING shows services, ONE total, ONE schedule and the '
        'lane-correct hire CTA', (tester) async {
      await _pumpDetail(
        tester,
        _booking(
          lane: BookingLane.standard,
          status: BookingStatus.pending,
          items: const [_acService, _installService],
        ),
      );

      // Each selected service with its own price.
      expect(find.text('AC General Service'), findsOneWidget);
      expect(find.text('Split AC Installation'), findsOneWidget);
      expect(find.text('Rs 2,500'), findsOneWidget);
      expect(find.text('Rs 3,500'), findsOneWidget);

      // The total appears EXACTLY once as a total, and once more only as the
      // summary's single authoritative price — never as two competing totals
      // computed by different precedence rules.
      expect(find.text('Rs 6,000'), findsNWidgets(2));
      expect(find.text('Total'), findsOneWidget);
      expect(find.text('Agreed Price'), findsOneWidget);

      // ONE schedule block: never Timing + Time Window + Scheduled Date.
      expect(find.textContaining('17 Aug 2026 · Afternoon'), findsOneWidget);
      expect(find.text('Schedule'), findsOneWidget);
      expect(find.text('Time Window'), findsNothing);
      expect(find.text('Scheduled Date'), findsNothing);
      expect(find.text('Timing'), findsNothing);

      // Status + urgency, once each.
      expect(find.text('Live'), findsOneWidget);
      expect(find.text('Normal'), findsOneWidget);

      // STANDARD hires directly; the bidding CTA must never appear.
      expect(find.byKey(const Key('choose-ustaad-button')), findsOneWidget);
      expect(find.byKey(const Key('find-workers-button')), findsNothing);
      expect(find.byKey(const Key('edit-booking-button')), findsOneWidget);
      expect(find.byKey(const Key('cancel-booking-button')), findsOneWidget);
    });

    testWidgets('assigned worker card carries rating, Call and Chat, with '
        'Track outside it and no map anywhere', (tester) async {
      await _pumpDetail(
        tester,
        _booking(
          status: BookingStatus.accepted,
          worker: _worker,
          items: const [_acService],
        ),
      );

      expect(find.text('Ali Khan'), findsOneWidget);
      expect(find.text('4.6'), findsOneWidget);
      // Call and Chat live INSIDE the worker card — exactly one of each, not
      // duplicated into a separate bottom action bar.
      expect(find.text('Call Worker'), findsOneWidget);
      expect(find.text('Chat with Worker'), findsOneWidget);
      expect(find.byKey(const Key('track-worker-button')), findsOneWidget);

      // The map moved to Track Ustaad. Booking Detail must embed none of it.
      expect(find.byType(GoogleMap), findsNothing);
    });

    testWidgets('worker-owned transitions are shown by the timeline and are '
        'never client buttons', (tester) async {
      for (final (status, label) in const [
        (BookingStatus.enRoute, 'On the way'),
        (BookingStatus.arrived, 'Arrived'),
        (BookingStatus.inProgress, 'Work started'),
      ]) {
        await _pumpDetail(
          tester,
          _booking(status: status, worker: _worker, items: const [_acService]),
        );

        // Progress is stated by the read-only timeline. (The status badge may
        // independently carry the same word — its wording is locked to the
        // Bookings tab and is deliberately untouched here.)
        expect(
          find.descendant(
            of: find.byKey(const Key('booking-timeline-section')),
            matching: find.text(label),
          ),
          findsOneWidget,
          reason: '$status must be shown as a read-only timeline step',
        );
        // Nothing that mutates EN_ROUTE / ARRIVED / IN_PROGRESS exists here.
        expect(find.widgetWithText(FilledButton, label), findsNothing);
        expect(find.widgetWithText(OutlinedButton, label), findsNothing);
        expect(find.widgetWithText(TextButton, label), findsNothing);
        // Cancelling is over once the Ustaad is moving — backend rule.
        expect(find.byKey(const Key('cancel-booking-button')), findsNothing);
        expect(find.byKey(const Key('track-worker-button')), findsOneWidget);
      }
    });

    testWidgets('worker cancellation shows the reason and a Hire New Ustaad '
        'CTA', (tester) async {
      await _pumpDetail(
        tester,
        _booking(
          status: BookingStatus.cancelled,
          cancelledByRole: CancelledByRole.worker,
          cancellationReason: 'Emergency at home',
          items: const [_acService],
        ),
      );

      expect(find.byKey(const Key('worker-cancelled-section')), findsOneWidget);
      expect(find.textContaining('Emergency at home'), findsOneWidget);
      expect(find.byKey(const Key('hire-new-ustaad-button')), findsOneWidget);
      // A cancelled booking is terminal: no tracking, no cancelling again.
      expect(find.byKey(const Key('track-worker-button')), findsNothing);
      expect(find.byKey(const Key('cancel-booking-button')), findsNothing);
    });

    testWidgets('a client cancellation still shows its recorded reason, with '
        'no rehire CTA', (tester) async {
      await _pumpDetail(
        tester,
        _booking(
          status: BookingStatus.cancelled,
          cancelledByRole: CancelledByRole.client,
          cancellationReason: 'Changed my mind',
          items: const [_acService],
        ),
      );

      expect(find.byKey(const Key('booking-cancelled-notice')), findsOneWidget);
      expect(find.textContaining('Changed my mind'), findsOneWidget);
      // Rehiring is only offered when the Ustaad walked away, not the client.
      expect(find.byKey(const Key('worker-cancelled-section')), findsNothing);
      expect(find.byKey(const Key('hire-new-ustaad-button')), findsNothing);
    });

    testWidgets('EXPIRED offers Make Live Again and no hire CTA', (
      tester,
    ) async {
      await _pumpDetail(
        tester,
        _booking(status: BookingStatus.expired, items: const [_acService]),
      );

      expect(find.byKey(const Key('make-live-again-button')), findsOneWidget);
      expect(find.byKey(const Key('choose-ustaad-button')), findsNothing);
      expect(find.byKey(const Key('find-workers-button')), findsNothing);
    });
  });

  group('COMPLETED is terminal on its own', () {
    testWidgets('the job reads as closed with no review, no complaint and no '
        'cash confirmed in this session', (tester) async {
      await _pumpDetail(
        tester,
        _booking(
          status: BookingStatus.completed,
          worker: _worker,
          items: const [_acService],
        ),
      );

      // Closed the moment the backend says COMPLETED — nothing else gates it.
      expect(find.byKey(const Key('job-closed-banner')), findsOneWidget);
      expect(find.text('Completed'), findsWidgets);
      // Post-completion actions are available, tracking is not.
      expect(find.byKey(const Key('review-worker-button')), findsOneWidget);
      expect(find.byKey(const Key('report-problem-button')), findsOneWidget);
      expect(find.byKey(const Key('track-worker-button')), findsNothing);
    });

    testWidgets('an existing review replaces the Review CTA', (tester) async {
      await _pumpDetail(
        tester,
        _booking(
          status: BookingStatus.completed,
          worker: _worker,
          items: const [_acService],
          review: BookingReviewEntity(
            id: 'r1',
            rating: 5,
            comment: 'Great work',
            createdAt: DateTime(2026, 8, 20),
          ),
        ),
      );

      expect(find.byKey(const Key('submitted-review-card')), findsOneWidget);
      expect(find.text('Great work'), findsOneWidget);
      expect(find.byKey(const Key('review-worker-button')), findsNothing);
      // The job was already closed; the review changed nothing about that.
      expect(find.byKey(const Key('job-closed-banner')), findsOneWidget);
    });

    testWidgets('AWAITING_CONFIRMATION and SETTLED read as completed, never '
        'as live, and expose no action the backend would reject', (
      tester,
    ) async {
      for (final status in const [
        BookingStatus.awaitingConfirmation,
        BookingStatus.settled,
      ]) {
        await _pumpDetail(
          tester,
          _booking(status: status, worker: _worker, items: const [_acService]),
        );

        // Same word the Bookings tab shows for these statuses.
        expect(find.text('Completed'), findsWidgets, reason: '$status');
        // Terminal: nobody to track.
        expect(
          find.byKey(const Key('track-worker-button')),
          findsNothing,
          reason: '$status must not offer tracking',
        );
        // submitReview and createForBooking both require COMPLETED, so
        // neither action may be offered here.
        expect(
          find.byKey(const Key('review-worker-button')),
          findsNothing,
          reason: '$status: review API would reject',
        );
        expect(
          find.byKey(const Key('report-problem-button')),
          findsNothing,
          reason: '$status: complaint API would reject',
        );
        expect(find.byKey(const Key('cancel-booking-button')), findsNothing);
      }
    });
  });

  group('BIDDING lane', () {
    testWidgets('before any bid is accepted the price is a dash and the only '
        'CTA is Find Workers', (tester) async {
      await _pumpDetail(
        tester,
        _booking(
          lane: BookingLane.bidding,
          status: BookingStatus.pending,
          title: 'Rewire the kitchen',
          description: 'Sockets keep tripping',
        ),
      );

      // Never Rs 0, never an estimate, never an inspection fee.
      expect(find.text('—'), findsOneWidget);
      expect(find.text('Price'), findsOneWidget);
      expect(find.textContaining('Rs 0'), findsNothing);
      expect(find.text('Agreed Price'), findsNothing);

      expect(find.byKey(const Key('find-workers-button')), findsOneWidget);
      expect(find.byKey(const Key('choose-ustaad-button')), findsNothing);

      expect(find.text('Rewire the kitchen'), findsOneWidget);
      expect(find.text('Sockets keep tripping'), findsOneWidget);
    });

    testWidgets('once a bid is accepted the accepted amount is the price', (
      tester,
    ) async {
      await _pumpDetail(
        tester,
        _booking(
          lane: BookingLane.bidding,
          status: BookingStatus.accepted,
          title: 'Rewire the kitchen',
          worker: _worker,
          acceptedBidAmount: 8200,
        ),
      );

      expect(find.text('Rs 8,200'), findsOneWidget);
      expect(find.text('—'), findsNothing);
      expect(find.text('Ali Khan'), findsOneWidget);
      expect(find.text('Call Worker'), findsOneWidget);
      expect(find.text('Chat with Worker'), findsOneWidget);
      expect(find.byKey(const Key('track-worker-button')), findsOneWidget);
    });

    testWidgets('an ATTACHED historical report opens READ-ONLY', (
      tester,
    ) async {
      final booking = _booking(
        lane: BookingLane.bidding,
        status: BookingStatus.pending,
        title: 'Rewire the kitchen',
        attachedInspectionBookingId: 'other-inspection',
      );
      await _pumpDetail(tester, booking, report: _report);

      expect(
        find.byKey(const Key('view-inspection-report-button')),
        findsOneWidget,
      );
      // Explicit read-only mode — NOT inferred from decisionStatus, which is
      // pendingClientDecision here and would otherwise expose Accept Quote /
      // Find Other Ustaad / Close for a DIFFERENT booking's inspection.
      expect(
        BookingActionSection.inspectionReportRoute(booking),
        '/client/booking/$_bookingId/inspection-report?readOnly=1',
      );
    });

    testWidgets('a linked repair booking also opens its source report '
        'READ-ONLY', (tester) async {
      final booking = _booking(
        lane: BookingLane.bidding,
        status: BookingStatus.pending,
        title: 'Repair after inspection',
        sourceInspectionBookingId: 'source-inspection',
      );
      await _pumpDetail(tester, booking, report: _report);

      expect(
        BookingActionSection.inspectionReportRoute(booking),
        '/client/booking/$_bookingId/inspection-report?readOnly=1',
      );
      // The lane switch is preserved: this is a BIDDING job, so it finds
      // workers rather than choosing one directly.
      expect(find.byKey(const Key('find-workers-button')), findsOneWidget);
      expect(find.byKey(const Key('choose-ustaad-button')), findsNothing);
    });
  });

  group('INSPECTION lane', () {
    testWidgets('shows the inspection fee as the price and the fee state', (
      tester,
    ) async {
      await _pumpDetail(
        tester,
        _booking(
          lane: BookingLane.inspection,
          status: BookingStatus.accepted,
          worker: _worker,
          inspectingWorker: _worker,
          inspectionFeeSnapshot: 900,
          inspectionFeePaid: false,
        ),
      );

      expect(find.text('Rs 900'), findsOneWidget);
      expect(find.text('Inspection fee not paid'), findsOneWidget);
      expect(find.byKey(const Key('inspection-status-strip')), findsOneWidget);
      // Same Ustaad inspected and will repair — ONE worker card, no second.
      expect(find.text('Inspection & repair by'), findsOneWidget);
      expect(find.text('Inspection completed by'), findsNothing);
    });

    testWidgets('the accepted repair quote replaces the fee as the price', (
      tester,
    ) async {
      await _pumpDetail(
        tester,
        _booking(
          lane: BookingLane.inspection,
          status: BookingStatus.inProgress,
          worker: _worker,
          inspectingWorker: _worker,
          inspectionFeeSnapshot: 900,
          finalPrice: 7400,
          inspectionReportSubmitted: true,
          inspectionDecisionStatus: InspectionDecisionStatus.acceptedRepair,
        ),
      );

      expect(find.text('Rs 7,400'), findsOneWidget);
      expect(find.text('Rs 900'), findsNothing);
    });

    testWidgets('closed after inspection keeps the fee-only outcome', (
      tester,
    ) async {
      await _pumpDetail(
        tester,
        _booking(
          lane: BookingLane.inspection,
          status: BookingStatus.completed,
          worker: _worker,
          inspectingWorker: _worker,
          inspectionFeeSnapshot: 900,
          inspectionReportSubmitted: true,
          inspectionDecisionStatus:
              InspectionDecisionStatus.closedAfterInspection,
          inspectionFeePaid: true,
        ),
      );

      expect(find.text('Inspection Fee'), findsOneWidget);
      expect(find.text('Rs 900'), findsOneWidget);
      expect(find.text('Inspection fee paid'), findsOneWidget);
    });

    testWidgets('View Inspection Report appears only once a report exists', (
      tester,
    ) async {
      final booking = _booking(
        lane: BookingLane.inspection,
        status: BookingStatus.inProgress,
        worker: _worker,
        inspectingWorker: _worker,
        inspectionFeeSnapshot: 900,
      );

      await _pumpDetail(tester, booking);
      expect(
        find.byKey(const Key('view-inspection-report-button')),
        findsNothing,
      );

      await _pumpDetail(tester, booking, report: _report);
      expect(
        find.byKey(const Key('view-inspection-report-button')),
        findsOneWidget,
      );
      // This booking OWNS its inspection, so the report page keeps its live
      // decision buttons.
      expect(
        BookingActionSection.inspectionReportRoute(booking),
        '/client/booking/$_bookingId/inspection-report',
      );
    });

    testWidgets('a different repair Ustaad gets the primary card while the '
        'inspector gets one compact row', (tester) async {
      await _pumpDetail(
        tester,
        _booking(
          lane: BookingLane.inspection,
          status: BookingStatus.inProgress,
          worker: _worker,
          inspectingWorker: _inspector,
          inspectionFeeSnapshot: 900,
          inspectionReportSubmitted: true,
          inspectionDecisionStatus: InspectionDecisionStatus.findOtherUstaad,
        ),
      );

      // Both identities are represented, but only the active Ustaad gets the
      // full card with Call/Chat.
      expect(find.text('Work being completed by'), findsOneWidget);
      expect(find.text('Ali Khan'), findsOneWidget);
      expect(find.text('Inspection completed by'), findsOneWidget);
      expect(find.text('Bilal Ahmed'), findsOneWidget);
      expect(find.text('Call Worker'), findsOneWidget);
      expect(find.text('Chat with Worker'), findsOneWidget);
    });
  });

  group('payment is server truth, and survives leaving the page', () {
    testWidgets('UNPAID before completion invites nothing and confirms '
        'nothing', (tester) async {
      await _pumpDetail(
        tester,
        _booking(
          status: BookingStatus.accepted,
          worker: _worker,
          items: const [_acService],
        ),
      );

      expect(find.text('Payment'), findsWidgets);
      expect(find.text('Unpaid'), findsOneWidget);
      expect(find.text('Cash — after work'), findsOneWidget);
      // Cash can only be confirmed for a COMPLETED booking.
      expect(find.byKey(const Key('confirm-cash-button')), findsNothing);
    });

    testWidgets('COMPLETED with no settlement offers the cash confirmation', (
      tester,
    ) async {
      await _pumpDetail(
        tester,
        _booking(
          status: BookingStatus.completed,
          worker: _worker,
          items: const [_acService],
        ),
      );

      expect(find.byKey(const Key('confirm-cash-button')), findsOneWidget);
      expect(find.text('Unpaid'), findsOneWidget);
    });

    testWidgets('PARTIAL shows paid and remaining from the server, and never '
        'the empty cash form again', (tester) async {
      await _pumpDetail(
        tester,
        _booking(
          status: BookingStatus.completed,
          worker: _worker,
          items: const [_acService],
          payment: PaymentDisplayStatus.partial,
          receivedAmount: 1000,
          expectedAmount: 2500,
          remainingAmount: 1500,
        ),
      );

      expect(find.text('Partial'), findsOneWidget);
      expect(find.text('Rs 1,000 paid · Rs 1,500 remaining'), findsOneWidget);
      expect(find.text('Cash received'), findsOneWidget);
      expect(find.text('Remaining'), findsOneWidget);
      // A settlement already exists: reopening the page must not ask again.
      expect(find.byKey(const Key('confirm-cash-button')), findsNothing);
    });

    testWidgets('PAID shows the paid state and no confirmation prompt', (
      tester,
    ) async {
      await _pumpDetail(
        tester,
        _booking(
          status: BookingStatus.completed,
          worker: _worker,
          items: const [_acService],
          payment: PaymentDisplayStatus.paid,
          receivedAmount: 2500,
          expectedAmount: 2500,
          remainingAmount: 0,
        ),
      );

      expect(find.text('Paid'), findsWidgets);
      expect(find.byKey(const Key('confirm-cash-button')), findsNothing);
    });

    testWidgets('review eligibility comes from the booking, not from a cash '
        'confirmation made in this session', (tester) async {
      // Nothing was confirmed in THIS session — the settlement is server
      // state from an earlier one. The review must still be offered.
      await _pumpDetail(
        tester,
        _booking(
          status: BookingStatus.completed,
          worker: _worker,
          items: const [_acService],
          payment: PaymentDisplayStatus.paid,
          receivedAmount: 2500,
          expectedAmount: 2500,
          remainingAmount: 0,
        ),
      );

      expect(find.byKey(const Key('review-worker-button')), findsOneWidget);
    });

    testWidgets('booking status and payment status are shown as separate '
        'facts', (tester) async {
      await _pumpDetail(
        tester,
        _booking(
          status: BookingStatus.completed,
          worker: _worker,
          items: const [_acService],
          payment: PaymentDisplayStatus.partial,
          receivedAmount: 1000,
          expectedAmount: 2500,
          remainingAmount: 1500,
        ),
      );

      // "Booking: Completed" next to "Payment: Partial" — a payment state
      // never redefines the booking lifecycle.
      expect(find.text('Booking'), findsOneWidget);
      expect(find.text('Completed'), findsWidgets);
      expect(find.text('Partial'), findsOneWidget);
    });
  });

  group('report / complaint', () {
    testWidgets('COMPLETED with no complaint offers exactly one create CTA '
        'and no status banner', (tester) async {
      await _pumpDetail(
        tester,
        _booking(
          status: BookingStatus.completed,
          worker: _worker,
          items: const [_acService],
        ),
      );

      expect(find.byKey(const Key('report-problem-button')), findsOneWidget);
      expect(find.byKey(const Key('report-status-banner')), findsNothing);
      expect(find.byKey(const Key('existing-report-section')), findsNothing);
    });

    testWidgets('an existing complaint shows a top status banner and no '
        'second create button', (tester) async {
      await _pumpDetail(
        tester,
        _booking(
          status: BookingStatus.completed,
          worker: _worker,
          items: const [_acService],
        ),
        complaint: _complaint(),
      );

      expect(find.byKey(const Key('report-status-banner')), findsOneWidget);
      expect(find.text('Report · Pending'), findsOneWidget);
      // Exactly one full report surface, and no way to create a duplicate.
      expect(find.byKey(const Key('existing-report-section')), findsOneWidget);
      expect(find.byKey(const Key('report-problem-button')), findsNothing);
      // The report detail stays reachable.
      expect(find.text('Work quality issue'), findsOneWidget);
      expect(find.textContaining('complaint-1'), findsOneWidget);
      expect(find.byKey(const Key('talk-to-support-button')), findsOneWidget);
    });

    testWidgets('every complaint status maps to the locked client wording', (
      tester,
    ) async {
      for (final (status, label) in const [
        (ComplaintStatus.open, 'Report · Pending'),
        (ComplaintStatus.inProgress, 'Report · Under review'),
        (ComplaintStatus.waitingOnCustomer, 'Report · Under review'),
        (ComplaintStatus.resolved, 'Report · Resolved'),
        (ComplaintStatus.closed, 'Report · Resolved'),
      ]) {
        await _pumpDetail(
          tester,
          _booking(
            status: BookingStatus.completed,
            worker: _worker,
            items: const [_acService],
          ),
          complaint: _complaint(status: status),
        );
        expect(find.text(label), findsOneWidget, reason: '$status');
      }
    });

    testWidgets('a human request that already happened is stated, not '
        'offered again', (tester) async {
      await _pumpDetail(
        tester,
        _booking(
          status: BookingStatus.completed,
          worker: _worker,
          items: const [_acService],
        ),
        complaint: _complaint(humanRequested: true),
      );

      expect(find.byKey(const Key('talk-to-support-button')), findsNothing);
      expect(find.text('The support team has been notified.'), findsOneWidget);
    });
  });

  group('responsive and theming', () {
    testWidgets('no overflow from 320 to 600 px, any lane', (tester) async {
      for (final width in const [320.0, 360.0, 390.0, 430.0, 600.0]) {
        await _pumpDetail(
          tester,
          _booking(
            lane: BookingLane.inspection,
            status: BookingStatus.completed,
            worker: _worker,
            inspectingWorker: _inspector,
            inspectionFeeSnapshot: 900,
            inspectionFeePaid: true,
            inspectionReportSubmitted: true,
            inspectionDecisionStatus: InspectionDecisionStatus.findOtherUstaad,
            payment: PaymentDisplayStatus.partial,
            receivedAmount: 400,
            expectedAmount: 900,
            remainingAmount: 500,
          ),
          complaint: _complaint(status: ComplaintStatus.inProgress),
          report: _report,
          surface: Size(width, 2200),
        );
        expect(tester.takeException(), isNull, reason: 'width $width');
      }
    });

    testWidgets('long service names and prices survive 320 px', (tester) async {
      await _pumpDetail(
        tester,
        _booking(
          items: const [
            BookingStandardServiceItemEntity(
              id: 'long',
              nameSnapshot:
                  'Split AC deep chemical wash with gas top-up and drainage flush',
              priceSnapshot: 128500,
              quantity: 3,
            ),
          ],
        ),
        surface: const Size(320, 1800),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders from semantic tokens in dark theme', (tester) async {
      await _pumpDetail(
        tester,
        _booking(
          status: BookingStatus.completed,
          worker: _worker,
          items: const [_acService],
          payment: PaymentDisplayStatus.paid,
          receivedAmount: 2500,
          expectedAmount: 2500,
          remainingAmount: 0,
        ),
        complaint: _complaint(status: ComplaintStatus.resolved),
        theme: AppTheme.darkTheme,
      );

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('job-closed-banner')), findsOneWidget);
      expect(find.text('Report · Resolved'), findsOneWidget);
    });

    testWidgets('renders in Roman Urdu without overflow', (tester) async {
      await _pumpDetail(
        tester,
        _booking(
          lane: BookingLane.bidding,
          status: BookingStatus.pending,
          title: 'Kitchen ki wiring',
        ),
        locale: AppLocale.romanUrdu,
        surface: const Size(360, 1800),
      );

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('find-workers-button')), findsOneWidget);
      expect(find.text('—'), findsOneWidget);
    });
  });
}
