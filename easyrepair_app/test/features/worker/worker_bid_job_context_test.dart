import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handygo_app/features/bids/presentation/providers/bid_providers.dart';
import 'package:handygo_app/features/bookings/domain/entities/booking_entity.dart';
import 'package:handygo_app/features/bookings/domain/entities/inspection_report_entity.dart';
import 'package:handygo_app/features/bookings/presentation/providers/booking_providers.dart';
import 'package:handygo_app/features/worker/presentation/pages/worker_bid_page.dart';
import 'package:handygo_app/features/worker/presentation/providers/worker_job_providers.dart';

import '../../support/l10n_test_app.dart';

/// The bid screen is where an Ustaad decides on a number, and the New Jobs
/// card's "Bid" button lands here directly — skipping the job detail screen.
/// So everything the customer supplied with the job has to be readable here,
/// before the bid exists and before anyone is hired.
void main() {
  BookingEntity job({
    List<BookingAttachmentEntity> attachments = const [],
    String? sourceInspectionBookingId,
    String? attachedInspectionBookingId,
  }) => BookingEntity(
    id: 'job-1',
    referenceId: '#HG-1',
    serviceCategory: 'Plumber',
    serviceEmoji: 'P',
    status: BookingStatus.pending,
    urgency: BookingUrgency.normal,
    createdAt: DateTime.utc(2026, 9, 1, 9),
    lane: BookingLane.bidding,
    city: 'Karachi',
    attachments: attachments,
    sourceInspectionBookingId: sourceInspectionBookingId,
    attachedInspectionBookingId: attachedInspectionBookingId,
  );

  final photo = BookingAttachmentEntity(
    id: 'att-1',
    type: AttachmentType.image,
    url: 'https://cdn.test/leak.jpg',
    createdAt: DateTime.utc(2026, 9, 1, 9),
  );

  final report = InspectionReportEntity(
    id: 'report-1',
    bookingId: 'job-1',
    partsNeeded: false,
    decisionStatus: InspectionDecisionStatus.findOtherUstaad,
    createdAt: DateTime.utc(2026, 9, 1, 9),
  );

  Future<void> pumpBidPage(
    WidgetTester tester, {
    required BookingEntity detail,
    bool reportAvailable = false,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          workerJobDetailProvider.overrideWith((ref, id) async => detail),
          myBidProvider.overrideWith((ref, id) async => null),
          jobBidsFeedProvider.overrideWith((ref, id) async => []),
          inspectionReportProvider.overrideWith(
            (ref, id) async => reportAvailable
                ? report
                : throw Exception('not an eligible viewer'),
          ),
        ],
        child: localizedApp(
          const WorkerBidPage(jobId: 'job-1', jobTitle: 'Leaking pipe'),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'shows the client\'s attachments before any bid has been placed',
    (tester) async {
      await pumpBidPage(tester, detail: job(attachments: [photo]));

      expect(
        find.byKey(const Key('bid-job-attachments-section')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'offers the inspection report on a Find-Other-Ustaad repair job before bidding',
    (tester) async {
      await pumpBidPage(
        tester,
        detail: job(sourceInspectionBookingId: 'inspection-1'),
        reportAvailable: true,
      );

      expect(
        find.byKey(const Key('view-inspection-report-button')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'offers a report the client attached to an ordinary bidding job',
    (tester) async {
      await pumpBidPage(
        tester,
        detail: job(attachedInspectionBookingId: 'old-inspection-1'),
        reportAvailable: true,
      );

      expect(
        find.byKey(const Key('view-inspection-report-button')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'hides the report entry point when this Ustaad is not an eligible viewer',
    (tester) async {
      await pumpBidPage(
        tester,
        detail: job(sourceInspectionBookingId: 'inspection-1'),
        reportAvailable: false,
      );

      expect(
        find.byKey(const Key('view-inspection-report-button')),
        findsNothing,
      );
    },
  );

  testWidgets('adds nothing to a job with no attachments and no report', (
    tester,
  ) async {
    await pumpBidPage(tester, detail: job());

    expect(find.byKey(const Key('bid-job-attachments-section')), findsNothing);
    expect(
      find.byKey(const Key('view-inspection-report-button')),
      findsNothing,
    );
  });
}
