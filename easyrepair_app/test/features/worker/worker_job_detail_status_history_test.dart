import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handygo_app/features/bookings/domain/entities/booking_entity.dart';
import 'package:handygo_app/features/worker/presentation/pages/worker_job_detail_page.dart';
import 'package:handygo_app/features/worker/presentation/providers/worker_job_providers.dart';

import '../../support/l10n_test_app.dart';

void main() {
  testWidgets('Kaam ki tafseel keeps Status History and removes Timeline', (
    tester,
  ) async {
    final job = BookingEntity(
      id: 'job-1',
      referenceId: '#HG-1',
      serviceCategory: 'Electrician',
      serviceEmoji: 'E',
      status: BookingStatus.pending,
      urgency: BookingUrgency.normal,
      createdAt: DateTime.utc(2026, 9, 1, 9),
      lane: BookingLane.standard,
      city: 'Lahore',
      statusHistory: [
        BookingStatusHistoryEntry(
          id: 'history-1',
          status: BookingStatus.pending,
          createdAt: DateTime.utc(2026, 9, 1, 9),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          workerJobDetailProvider.overrideWith((ref, id) async => job),
        ],
        child: localizedApp(const WorkerJobDetailPage(jobId: 'job-1')),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('worker-status-history-section')),
      findsOneWidget,
    );
    expect(find.text('Status History'), findsOneWidget);
    expect(find.text('Timeline'), findsNothing);
  });
}
