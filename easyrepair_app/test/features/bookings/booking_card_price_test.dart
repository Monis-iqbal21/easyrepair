import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handygo_app/features/bookings/domain/entities/booking_entity.dart';
import 'package:handygo_app/features/bookings/presentation/widgets/booking_card.dart';

import '../../support/l10n_test_app.dart';

/// Client Bookings list/cards must show the real canonical price — never an
/// "estimate", never Rs 0/blank for an open BIDDING job.
BookingEntity _booking({
  required BookingLane lane,
  required BookingStatus status,
  double? estimatedPrice,
  double? finalPrice,
  double? acceptedBidAmount,
  double? inspectionFeeSnapshot,
  List<BookingStandardServiceItemEntity> standardServiceItems = const [],
  AssignedWorkerEntity? assignedWorker,
}) {
  return BookingEntity(
    id: 'b1',
    referenceId: '#HG-1',
    serviceCategory: 'Electrician',
    serviceEmoji: '⚡',
    status: status,
    urgency: BookingUrgency.normal,
    createdAt: DateTime(2026, 7, 1),
    lane: lane,
    estimatedPrice: estimatedPrice,
    finalPrice: finalPrice,
    acceptedBidAmount: acceptedBidAmount,
    inspectionFeeSnapshot: inspectionFeeSnapshot,
    standardServiceItems: standardServiceItems,
    assignedWorker: assignedWorker,
  );
}

const _worker = AssignedWorkerEntity(id: 'w1', firstName: 'Ali', lastName: 'Khan');

void main() {
  Future<void> pump(WidgetTester tester, BookingEntity booking) async {
    await tester.pumpWidget(
      localizedApp(
        Scaffold(body: BookingCard(booking: booking, onTap: () {})),
      ),
    );
  }

  group('BookingCard price tag', () {
    testWidgets('STANDARD: shows the fixed job price before any hire', (
      tester,
    ) async {
      await pump(
        tester,
        _booking(
          lane: BookingLane.standard,
          status: BookingStatus.pending,
          estimatedPrice: 9999,
          standardServiceItems: const [
            BookingStandardServiceItemEntity(
              id: 'i1',
              nameSnapshot: 'AC Service',
              priceSnapshot: 2500,
            ),
          ],
        ),
      );

      expect(find.text('Rs 2,500'), findsOneWidget);
      expect(find.text('Rs 9,999'), findsNothing);
    });

    testWidgets('BIDDING: shows no price tag before any bid is accepted', (
      tester,
    ) async {
      await pump(
        tester,
        _booking(
          lane: BookingLane.bidding,
          status: BookingStatus.pending,
          estimatedPrice: 3000,
        ),
      );

      expect(find.text('Rs 3,000'), findsNothing);
      expect(find.textContaining('Rs '), findsNothing);
    });

    testWidgets('BIDDING: shows only the accepted bid once hired', (
      tester,
    ) async {
      await pump(
        tester,
        _booking(
          lane: BookingLane.bidding,
          status: BookingStatus.accepted,
          estimatedPrice: 3000,
          acceptedBidAmount: 4500,
          assignedWorker: _worker,
        ),
      );

      expect(find.text('Rs 4,500'), findsOneWidget);
      expect(find.text('Rs 3,000'), findsNothing);
    });

    testWidgets('INSPECTION: shows the fee', (tester) async {
      await pump(
        tester,
        _booking(
          lane: BookingLane.inspection,
          status: BookingStatus.pending,
          inspectionFeeSnapshot: 500,
        ),
      );

      expect(find.text('Rs 500'), findsOneWidget);
    });

    testWidgets('never shows "Estimated"/"Estimate" wording anywhere', (
      tester,
    ) async {
      for (final booking in [
        _booking(
          lane: BookingLane.standard,
          status: BookingStatus.pending,
          estimatedPrice: 1000,
          standardServiceItems: const [
            BookingStandardServiceItemEntity(
              id: 'i1',
              nameSnapshot: 'Service',
              priceSnapshot: 1200,
            ),
          ],
        ),
        _booking(
          lane: BookingLane.bidding,
          status: BookingStatus.accepted,
          acceptedBidAmount: 4500,
          assignedWorker: _worker,
        ),
        _booking(
          lane: BookingLane.inspection,
          status: BookingStatus.pending,
          inspectionFeeSnapshot: 500,
        ),
      ]) {
        await pump(tester, booking);
        expect(find.textContaining('Estimat'), findsNothing);
        expect(find.textContaining('est.'), findsNothing);
      }
    });
  });
}
