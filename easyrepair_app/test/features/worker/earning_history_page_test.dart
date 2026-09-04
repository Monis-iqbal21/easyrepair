import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handygo_app/core/l10n/app_locale.dart';
import 'package:handygo_app/features/worker/domain/entities/earning_history_entity.dart';
import 'package:handygo_app/features/worker/presentation/pages/earning_history_page.dart';
import 'package:handygo_app/features/worker/presentation/providers/earning_history_providers.dart';

import '../../support/l10n_test_app.dart';

final _dayOne = EarningHistoryDayEntity(
  date: DateTime(2026, 8, 1),
  grossTotal: 10000,
  jobsCount: 1,
  jobs: [
    EarningHistoryJobEntity(
      bookingId: 'job-A',
      lane: 'STANDARD',
      serviceCategory: 'AC Repair',
      grossEarning: 10000,
      commissionAmount: 1800,
      ustaadEarning: 8200,
      commissionStatus: CommissionStatus.paid,
      completedAt: DateTime(2026, 8, 1, 9),
      isInspectionOnly: false,
    ),
  ],
);

final _dayTwo = EarningHistoryDayEntity(
  date: DateTime(2026, 8, 2),
  grossTotal: 5000,
  jobsCount: 1,
  jobs: [
    EarningHistoryJobEntity(
      bookingId: 'job-B',
      lane: 'STANDARD',
      serviceCategory: 'Plumbing',
      grossEarning: 5000,
      commissionAmount: 900,
      ustaadEarning: 4100,
      commissionStatus: CommissionStatus.pending,
      completedAt: DateTime(2026, 8, 2, 11),
      isInspectionOnly: false,
    ),
  ],
);

final _days = [_dayTwo, _dayOne];

final _dayWithMissingAmounts = EarningHistoryDayEntity(
  date: DateTime(2026, 8, 3),
  grossTotal: 3000,
  jobsCount: 1,
  jobs: [
    EarningHistoryJobEntity(
      bookingId: 'job-C',
      lane: 'STANDARD',
      serviceCategory: 'Wiring',
      grossEarning: 3000,
      commissionAmount: null,
      ustaadEarning: null,
      commissionStatus: CommissionStatus.pending,
      completedAt: DateTime(2026, 8, 3, 10),
      isInspectionOnly: false,
    ),
  ],
);

Future<void> _pump(
  WidgetTester tester, {
  AppLocale locale = AppLocale.romanUrdu,
  List<EarningHistoryDayEntity>? days,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        workerEarningsHistoryProvider.overrideWith(
          (ref) async => days ?? _days,
        ),
      ],
      child: localizedApp(const EarningHistoryPage(), locale: locale),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('displays gross earning for each job', (tester) async {
    await _pump(tester);
    // Each test day has exactly one job, so its gross also coincides with
    // that day's header total — hence `findsWidgets` (>=1) rather than an
    // exact count for these two, unlike the page-wide totals below.
    expect(find.text('Rs 10,000'), findsWidgets);
    expect(find.text('Rs 5,000'), findsWidgets);
  });

  testWidgets('displays the 18% HandyGo commission for each job', (
    tester,
  ) async {
    await _pump(tester);
    expect(find.text('Rs 1,800'), findsOneWidget);
    expect(find.text('Rs 900'), findsOneWidget);
  });

  testWidgets('displays backend-computed Ustaad profit for each job', (
    tester,
  ) async {
    await _pump(tester);
    expect(find.text('Rs 8,200'), findsOneWidget);
    expect(find.text('Rs 4,100'), findsOneWidget);
  });

  testWidgets(
    'displays Paid/Pending commission status per job, independently',
    (tester) async {
      await _pump(tester);
      expect(find.text('Paid'), findsOneWidget);
      expect(find.text('Pending'), findsOneWidget);
    },
  );

  testWidgets(
    'totals section sums Gross / Commission / Ustaad correctly across all jobs',
    (tester) async {
      await _pump(tester);
      // Job A (10000/1800/8200) + Job B (5000/900/4100).
      expect(find.text('Rs 15,000'), findsOneWidget);
      expect(find.text('Rs 2,700'), findsOneWidget);
      expect(find.text('Rs 12,300'), findsOneWidget);
    },
  );

  testWidgets('multilingual labels resolve in English', (tester) async {
    await _pump(tester, locale: AppLocale.english);
    expect(find.text('Labour Earnings'), findsWidgets);
    expect(find.text('HandyGo Commission (18%)'), findsWidgets);
    expect(find.text('Profit'), findsWidgets);
  });

  testWidgets('multilingual labels resolve in Roman Urdu (default)', (
    tester,
  ) async {
    await _pump(tester, locale: AppLocale.romanUrdu);
    expect(find.text('Labour'), findsWidgets);
    expect(find.text('HandyGo Commission (18%)'), findsWidgets);
    expect(find.text('Munafa'), findsWidgets);
  });

  testWidgets('multilingual labels resolve in Urdu', (tester) async {
    await _pump(tester, locale: AppLocale.urdu);
    expect(find.text('مزدوری'), findsWidgets);
    expect(find.text('منافع'), findsWidgets);
  });

  testWidgets('missing financial values show an em dash', (tester) async {
    await _pump(tester, days: [_dayWithMissingAmounts]);
    expect(find.text('—'), findsNWidgets(2));
    expect(find.text('Rs 540'), findsNothing);
    expect(find.text('Rs 3,000'), findsWidgets);
    expect(find.text('Rs 0'), findsNWidgets(2));
  });

  testWidgets('the empty state still renders when there are no earnings yet', (
    tester,
  ) async {
    await _pump(tester, locale: AppLocale.english, days: const []);
    expect(find.text('No earnings yet'), findsOneWidget);
  });

  testWidgets('the back button remains intact', (tester) async {
    await _pump(tester);
    expect(find.byIcon(Icons.arrow_back_ios_new_rounded), findsOneWidget);
  });
}
