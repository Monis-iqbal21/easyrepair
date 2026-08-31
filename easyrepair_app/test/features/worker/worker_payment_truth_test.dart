import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handygo_app/core/errors/failures.dart';
import 'package:handygo_app/core/l10n/app_locale.dart';
import 'package:handygo_app/core/l10n/l10n_config.dart';
import 'package:handygo_app/features/bookings/data/models/booking_model.dart';
import 'package:handygo_app/features/bookings/domain/entities/booking_entity.dart';
import 'package:handygo_app/features/worker/domain/entities/worker_payment_report_entity.dart';
import 'package:handygo_app/features/worker/presentation/providers/worker_job_providers.dart';
import 'package:handygo_app/features/worker/presentation/widgets/worker_payment_section.dart';

/// FIX 1 + FIX 3 — the Ustaad is shown the money that actually arrived, and
/// can say so when it did not. Every number here is the server's; the only
/// arithmetic this app is allowed is none.

// ── Fixtures ────────────────────────────────────────────────────────────────

/// The verified production case: parts 1700 + labour 1000 = 2700 expected,
/// 2500 received, so 144 commission / 656 munafa / 200 short.
BookingEntity _job({
  BookingStatus status = BookingStatus.completed,
  PaymentDisplayStatus paymentDisplayStatus = PaymentDisplayStatus.partial,
  double? receivedAmount = 2500,
  double? expectedAmount = 2700,
  double? remainingAmount = 200,
  double? commission = 144,
  double? munafa = 656,
  double? partsPaid = 1700,
  double? labourPaid = 800,
}) {
  return BookingEntity(
    id: 'job-1',
    referenceId: '#HG-1',
    serviceCategory: 'AC Technician',
    serviceEmoji: '❄️',
    status: status,
    urgency: BookingUrgency.normal,
    createdAt: DateTime(2026, 8, 30),
    lane: BookingLane.inspection,
    finalPrice: 2700,
    paymentDisplayStatus: paymentDisplayStatus,
    receivedAmount: receivedAmount,
    expectedAmount: expectedAmount,
    remainingAmount: remainingAmount,
    settlementCommission: commission,
    settlementMunafa: munafa,
    settlementPartsPaid: partsPaid,
    settlementLabourPaid: labourPaid,
    settlementFeePaid: 0,
  );
}

class _FakeReportNotifier extends ReportReceivedPaymentNotifier {
  _FakeReportNotifier({this.failure});

  final Failure? failure;
  final calls = <({String jobId, int amount})>[];

  @override
  Future<WorkerPaymentReportEntity?> build() async => null;

  @override
  Future<Failure?> report(String jobId, int receivedCashTotal) async {
    calls.add((jobId: jobId, amount: receivedCashTotal));
    if (failure != null) {
      state = AsyncError(failure!, StackTrace.current);
      return failure;
    }
    state = const AsyncData(
      WorkerPaymentReportEntity(
        expectedTotal: 2700,
        receivedCashTotal: 2500,
        partsPaid: 1700,
        labourPaid: 800,
        feePaid: 0,
        commission: 144,
        munafa: 656,
        shortfall: 200,
      ),
    );
    return null;
  }
}

Widget _wrap(BookingEntity job, {_FakeReportNotifier? notifier}) {
  return ProviderScope(
    overrides: [
      if (notifier != null)
        reportReceivedPaymentProvider.overrideWith(() => notifier),
    ],
    child: MaterialApp(
      locale: AppLocale.english.locale,
      supportedLocales: appSupportedLocales,
      localizationsDelegates: appLocalizationsDelegates,
      localeResolutionCallback: (_, _) => AppLocale.english.locale,
      home: Scaffold(
        body: SingleChildScrollView(child: WorkerPaymentSection(job: job)),
      ),
    ),
  );
}

void main() {
  // ── The wire ─────────────────────────────────────────────────────────────

  group('BookingModel settlement parsing', () {
    Map<String, dynamic> base() => {
      'id': 'job-1',
      'serviceCategory': 'AC Technician',
      'description': 'AC not cooling',
      'status': 'COMPLETED',
      'urgency': 'NORMAL',
      'createdAt': '2026-08-30T00:00:00.000Z',
    };

    test('carries the server allocation through without recomputing it', () {
      final entity = BookingModel.fromJson({
        ...base(),
        'paymentDisplayStatus': 'PARTIAL',
        'receivedAmount': 2500,
        'expectedAmount': 2700,
        'remainingAmount': 200,
        'settlementPartsPaid': 1700,
        'settlementLabourPaid': 800,
        'settlementFeePaid': 0,
        'settlementCommission': 144,
        'settlementMunafa': 656,
      }).toEntity();

      expect(entity.receivedAmount, 2500);
      expect(entity.expectedAmount, 2700);
      expect(entity.settlementCommission, 144);
      expect(entity.settlementMunafa, 656);
      expect(entity.hasPaymentShortfall, isTrue);
      expect(entity.canWorkerReportPayment, isFalse);
    });

    test('an older payload without the settlement keys invents nothing', () {
      final entity = BookingModel.fromJson(base()).toEntity();

      expect(entity.paymentDisplayStatus, PaymentDisplayStatus.unpaid);
      expect(entity.receivedAmount, isNull);
      expect(entity.settlementCommission, isNull);
      expect(entity.settlementMunafa, isNull);
      expect(entity.hasPaymentShortfall, isFalse);
      // Nothing recorded yet, so the Ustaad may still declare what they got.
      expect(entity.canWorkerReportPayment, isTrue);
    });

    test('copyWith never resets a settled booking back to unpaid', () {
      final entity = BookingModel.fromJson({
        ...base(),
        'paymentDisplayStatus': 'PAID',
        'receivedAmount': 2700,
        'expectedAmount': 2700,
        'remainingAmount': 0,
        'settlementCommission': 180,
        'settlementMunafa': 820,
      }).toEntity();

      final updated = entity.copyWith(status: BookingStatus.completed);

      expect(updated.paymentDisplayStatus, PaymentDisplayStatus.paid);
      expect(updated.receivedAmount, 2700);
      expect(updated.settlementCommission, 180);
      expect(updated.settlementMunafa, 820);
    });
  });

  // ── The screen ───────────────────────────────────────────────────────────

  testWidgets('shows expected, received, shortfall, commission and earning', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(_job()));
    await tester.pumpAndSettle();

    expect(find.text('Rs 2,700'), findsOneWidget); // expected
    expect(find.text('Rs 2,500'), findsOneWidget); // actually received
    expect(find.text('Rs 200'), findsOneWidget); // short
    expect(find.text('- Rs 144'), findsOneWidget); // server commission
    expect(find.text('Rs 656'), findsOneWidget); // server munafa

    expect(find.byKey(const Key('worker-payment-shortfall')), findsOneWidget);
    // Nothing left to declare once a settlement exists.
    expect(
      find.byKey(const Key('worker-report-payment-button')),
      findsNothing,
    );
  });

  testWidgets('a fully paid job shows no shortfall row', (tester) async {
    await tester.pumpWidget(
      _wrap(
        _job(
          paymentDisplayStatus: PaymentDisplayStatus.paid,
          receivedAmount: 2700,
          remainingAmount: 0,
          commission: 180,
          munafa: 820,
          labourPaid: 1000,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('worker-payment-shortfall')), findsNothing);
    expect(find.text('Rs 820'), findsOneWidget);
  });

  testWidgets('never presents the quoted price as money received', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        _job(
          paymentDisplayStatus: PaymentDisplayStatus.unpaid,
          receivedAmount: null,
          expectedAmount: null,
          remainingAmount: null,
          commission: null,
          munafa: null,
          partsPaid: null,
          labourPaid: null,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('worker-payment-received')), findsNothing);
    expect(find.byKey(const Key('worker-payment-commission')), findsNothing);
    // finalPrice is 2700 and must not leak in as a received amount.
    expect(find.text('Rs 2,700'), findsNothing);
    expect(find.text('Payment not recorded yet'), findsOneWidget);
    expect(
      find.byKey(const Key('worker-report-payment-button')),
      findsOneWidget,
    );
  });

  testWidgets('an unfinished job offers nothing to declare', (tester) async {
    await tester.pumpWidget(
      _wrap(
        _job(
          status: BookingStatus.inProgress,
          paymentDisplayStatus: PaymentDisplayStatus.unpaid,
          receivedAmount: null,
          expectedAmount: null,
          remainingAmount: null,
          commission: null,
          munafa: null,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('worker-report-payment-button')),
      findsNothing,
    );
  });

  // ── "Kam paisa mila" ─────────────────────────────────────────────────────

  testWidgets('sends the declared amount as a plain whole-rupee fact', (
    tester,
  ) async {
    final notifier = _FakeReportNotifier();
    await tester.pumpWidget(
      _wrap(
        _job(
          paymentDisplayStatus: PaymentDisplayStatus.unpaid,
          receivedAmount: null,
          expectedAmount: null,
          remainingAmount: null,
          commission: null,
          munafa: null,
        ),
        notifier: notifier,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('worker-report-payment-button')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('worker-report-payment-field')),
      '2500',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('worker-report-payment-submit')));
    await tester.pumpAndSettle();

    expect(notifier.calls, [(jobId: 'job-1', amount: 2500)]);
  });

  testWidgets('refuses an empty amount without a round trip', (tester) async {
    final notifier = _FakeReportNotifier();
    await tester.pumpWidget(
      _wrap(
        _job(
          paymentDisplayStatus: PaymentDisplayStatus.unpaid,
          receivedAmount: null,
          expectedAmount: null,
          remainingAmount: null,
          commission: null,
          munafa: null,
        ),
        notifier: notifier,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('worker-report-payment-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('worker-report-payment-submit')));
    await tester.pumpAndSettle();

    expect(notifier.calls, isEmpty);
    expect(
      find.text('Enter a whole rupee amount of 0 or more.'),
      findsOneWidget,
    );
  });

  testWidgets('accepts zero — "the customer paid nothing" is a real answer', (
    tester,
  ) async {
    final notifier = _FakeReportNotifier();
    await tester.pumpWidget(
      _wrap(
        _job(
          paymentDisplayStatus: PaymentDisplayStatus.unpaid,
          receivedAmount: null,
          expectedAmount: null,
          remainingAmount: null,
          commission: null,
          munafa: null,
        ),
        notifier: notifier,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('worker-report-payment-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('worker-report-payment-field')),
      '0',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('worker-report-payment-submit')));
    await tester.pumpAndSettle();

    expect(notifier.calls, [(jobId: 'job-1', amount: 0)]);
  });

  testWidgets("shows the server's own rejection rather than a generic one", (
    tester,
  ) async {
    final notifier = _FakeReportNotifier(
      failure: const ServerFailure(
        'Received cash cannot exceed the payable total',
        code: FailureCode.invalidRequest,
      ),
    );
    await tester.pumpWidget(
      _wrap(
        _job(
          paymentDisplayStatus: PaymentDisplayStatus.unpaid,
          receivedAmount: null,
          expectedAmount: null,
          remainingAmount: null,
          commission: null,
          munafa: null,
        ),
        notifier: notifier,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('worker-report-payment-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('worker-report-payment-field')),
      '99999',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('worker-report-payment-submit')));
    await tester.pumpAndSettle();

    expect(find.byType(SnackBar), findsOneWidget);
    expect(
      find.text('Received cash cannot exceed the payable total'),
      findsOneWidget,
    );
    // Sheet stays open so the amount can be corrected in place.
    expect(
      find.byKey(const Key('worker-report-payment-field')),
      findsOneWidget,
    );
    await tester.pump(const Duration(seconds: 5));
  });
}
