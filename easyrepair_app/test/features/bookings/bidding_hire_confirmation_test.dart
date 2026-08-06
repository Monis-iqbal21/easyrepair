import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handygo_app/core/l10n/app_locale.dart';
import 'package:handygo_app/features/bids/domain/entities/bid_entity.dart';
import 'package:handygo_app/features/bids/domain/repositories/bid_repository.dart';
import 'package:handygo_app/features/bids/presentation/providers/bid_providers.dart';
import 'package:handygo_app/features/bookings/domain/entities/booking_entity.dart';
import 'package:handygo_app/features/bookings/domain/entities/inspection_report_entity.dart';
import 'package:handygo_app/features/bookings/presentation/pages/worker_discovery_map_page.dart';
import 'package:handygo_app/features/bookings/presentation/providers/booking_providers.dart';

import '../../support/l10n_test_app.dart';

/// Covers the hire-confirmation modal's origin-aware explanatory note:
///  * A direct BIDDING booking (client picked BIDDING themselves) shows the
///    labour-only warning — parts/materials are separate.
///  * A BIDDING booking spawned by "Inspection → Find Other Ustaad" shows the
///    report-inclusive note instead, and never the labour-only warning.
/// Neither flow changes the accepted bid amount, the Hire button, or worker
/// selection — this only adds the conditional text.

const _labourOnlyEn =
    'This bid covers labour only. Parts and materials will be purchased or '
    'charged separately with your approval.';
const _labourOnlyRomanUrdu =
    'Yeh bid sirf labour charges ke liye hai. Parts aur material aap ki '
    'approval se alag khareede ya charge kiye jayenge.';
const _labourOnlyUrdu =
    'یہ بولی صرف مزدوری کے اخراجات کے لیے ہے۔ پرزے اور سامان آپ کی منظوری '
    'سے الگ خریدے یا چارج کیے جائیں گے۔';

const _inspectionBasedEn =
    'This bid is based on the inspection report and includes labour and '
    'the parts or materials required for the reported work.';
const _inspectionBasedRomanUrdu =
    'Yeh bid inspection report ke mutabiq hai aur is mein labour aur '
    'report ke kaam ke liye zaroori parts ya material shamil hain.';
const _inspectionBasedUrdu =
    'یہ بولی انسپیکشن رپورٹ کے مطابق ہے اور اس میں مزدوری اور رپورٹ کیے '
    'گئے کام کے لیے درکار پرزے یا سامان شامل ہیں۔';

const _hireLabel = {
  AppLocale.english: 'Hire',
  AppLocale.romanUrdu: 'Hire karein',
  AppLocale.urdu: 'ہائر کریں',
};

/// A BIDDING booking the client created directly — never touched an
/// inspection, so there is no pinned inspecting worker.
BookingEntity _directBiddingBooking() {
  return BookingEntity(
    id: 'direct-1',
    referenceId: '#ER-DIRECT1',
    serviceCategory: 'Plumbing',
    serviceEmoji: '🔧',
    description: 'Leaky pipe',
    status: BookingStatus.pending,
    urgency: BookingUrgency.normal,
    createdAt: DateTime(2026, 7, 30, 11),
    lane: BookingLane.bidding,
    city: 'Karachi',
    latitude: 24.86,
    longitude: 67.0,
  );
}

/// The linked BIDDING repair booking spawned by "Find Other Ustaad" — carries
/// the pinned inspecting Ustaad and sourceInspectionBookingId, same shape
/// used elsewhere for this flow (see inspector_busy_rehire_test.dart).
BookingEntity _postInspectionBiddingBooking() {
  return BookingEntity(
    id: 'child-1',
    referenceId: '#ER-CHILD1',
    serviceCategory: 'AC Repair',
    serviceEmoji: '❄️',
    description: 'Leaky pipe\n\nReplace pipe',
    status: BookingStatus.pending,
    urgency: BookingUrgency.normal,
    createdAt: DateTime(2026, 7, 30, 11),
    lane: BookingLane.bidding,
    city: 'Karachi',
    latitude: 24.86,
    longitude: 67.0,
    sourceInspectionBookingId: 'booking-1',
    inspectingWorker: const AssignedWorkerEntity(
      id: 'inspector-1',
      firstName: 'Ali',
      lastName: 'Khan',
      rating: 4.6,
    ),
  );
}

InspectionReportEntity _report() => InspectionReportEntity(
      id: 'report-1',
      bookingId: 'booking-1',
      workerProfileId: 'inspector-1',
      issueFound: 'Leaky pipe',
      recommendedRepair: 'Replace pipe',
      labourCost: 3000,
      partsNeeded: false,
      partsTotal: 0,
      repairQuoteTotal: 3000,
      decisionStatus: InspectionDecisionStatus.findOtherUstaad,
      createdAt: DateTime(2026, 7, 30, 10),
      linkedRepairBookingId: 'child-1',
    );

BidWithWorkerEntity _bid({required String bookingId}) {
  return BidWithWorkerEntity(
    bid: BidEntity(
      id: 'bid-1',
      bookingId: bookingId,
      workerProfileId: 'worker-2',
      amount: 2500,
      status: BidStatus.pending,
      editCount: 0,
      createdAt: DateTime(2026, 7, 30, 12),
      updatedAt: DateTime(2026, 7, 30, 12),
    ),
    workerProfileId: 'worker-2',
    firstName: 'Bilal',
    lastName: 'Ahmed',
    rating: 4.2,
    completedJobs: 8,
    distanceKm: 3.1,
    skills: const ['AC Repair'],
    currentLat: 24.87,
    currentLng: 67.01,
  );
}

void main() {
  setUp(() {
    final view = TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .views
        .first;
    view.physicalSize = const Size(1080, 2340);
    view.devicePixelRatio = 3.0;
  });

  tearDown(() {
    final view = TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .views
        .first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  /// Pumps the bidding page for [booking], opens the offers sheet, and taps
  /// the competing bidder's "Hire" button to open the confirmation dialog.
  Future<void> openHireDialog(
    WidgetTester tester,
    BookingEntity booking, {
    AppLocale locale = AppLocale.english,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bookingBidsProvider(
            booking.id,
          ).overrideWith((_) async => [_bid(bookingId: booking.id)]),
          if (booking.inspectingWorker != null)
            inspectionReportProvider(
              booking.id,
            ).overrideWith((_) async => _report()),
        ],
        child: localizedApp(
          WorkerDiscoveryMapPage(booking: booking),
          locale: locale,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final hireLabel = _hireLabel[locale]!;

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -320));
    await tester.pumpAndSettle();

    // The card's hire button is FilledButton.icon (a FilledButton subclass
    // find.byType wouldn't match by exact type), so target it by its label
    // text instead — unambiguous here since only the bid card's button
    // carries this text before the dialog opens.
    await tester.dragUntilVisible(
      find.text(hireLabel),
      find.byType(CustomScrollView),
      const Offset(0, -60),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text(hireLabel));
    await tester.pumpAndSettle();
  }

  group('Direct BIDDING lane', () {
    testWidgets('hire dialog shows the labour-only note', (tester) async {
      await openHireDialog(tester, _directBiddingBooking());

      expect(find.text(_labourOnlyEn), findsOneWidget);
      expect(find.text(_inspectionBasedEn), findsNothing);
    });

    testWidgets('never shows the inspection-origin note', (tester) async {
      await openHireDialog(tester, _directBiddingBooking());
      expect(find.text(_inspectionBasedEn), findsNothing);
    });

    testWidgets('accepted bid amount and Hire button are unchanged', (
      tester,
    ) async {
      await openHireDialog(tester, _directBiddingBooking());

      expect(find.textContaining('2,500'), findsWidgets);
      // One "Hire" label on the card behind the dialog, one to confirm
      // inside the dialog — both still say plain "Hire", untouched.
      expect(find.text('Hire'), findsNWidgets(2));
    });

    testWidgets('renders in Roman Urdu', (tester) async {
      await openHireDialog(
        tester,
        _directBiddingBooking(),
        locale: AppLocale.romanUrdu,
      );
      expect(find.text(_labourOnlyRomanUrdu), findsOneWidget);
    });

    testWidgets('renders in Urdu', (tester) async {
      await openHireDialog(
        tester,
        _directBiddingBooking(),
        locale: AppLocale.urdu,
      );
      expect(find.text(_labourOnlyUrdu), findsOneWidget);
    });
  });

  group('Inspection → Find Other Ustaad → Bidding lane', () {
    testWidgets('hire dialog shows the report-inclusive note', (
      tester,
    ) async {
      await openHireDialog(tester, _postInspectionBiddingBooking());

      expect(find.text(_inspectionBasedEn), findsOneWidget);
      expect(find.text(_labourOnlyEn), findsNothing);
    });

    testWidgets('never shows the labour-only note', (tester) async {
      await openHireDialog(tester, _postInspectionBiddingBooking());
      expect(find.text(_labourOnlyEn), findsNothing);
    });

    testWidgets('renders in Roman Urdu', (tester) async {
      await openHireDialog(
        tester,
        _postInspectionBiddingBooking(),
        locale: AppLocale.romanUrdu,
      );
      expect(find.text(_inspectionBasedRomanUrdu), findsOneWidget);
    });

    testWidgets('renders in Urdu', (tester) async {
      await openHireDialog(
        tester,
        _postInspectionBiddingBooking(),
        locale: AppLocale.urdu,
      );
      expect(find.text(_inspectionBasedUrdu), findsOneWidget);
    });
  });
}
