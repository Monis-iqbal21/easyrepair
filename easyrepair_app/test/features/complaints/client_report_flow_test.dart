import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:go_router/go_router.dart';
import 'package:handygo_app/core/errors/failures.dart';
import 'package:handygo_app/core/theme/app_theme.dart';
import 'package:handygo_app/features/bookings/domain/entities/booking_entity.dart';
import 'package:handygo_app/features/complaints/domain/entities/complaint_entity.dart';
import 'package:handygo_app/features/complaints/domain/repositories/complaint_repository.dart';
import 'package:handygo_app/features/complaints/presentation/pages/report_problem_page.dart';
import 'package:handygo_app/features/complaints/presentation/providers/complaint_providers.dart';
import 'package:handygo_app/features/complaints/presentation/widgets/booking_complaint_section.dart';
import 'package:handygo_app/l10n/app_localizations.dart';

/// The Report form lists seven issue options plus a helper line, a bottom CTA
/// bar and (when OTHER is picked) a multi-line field. That is taller than the
/// default 800x600 test surface, and a ListView never builds what is below the
/// fold - so an un-resized surface makes the later options untappable rather
/// than merely off-screen. Every test that taps an option sets a tall surface.
Future<void> _useTallSurface(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(420, 1600));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

void main() {
  testWidgets('completed booking creates one report and immediately shows it',
      (tester) async {
    await _useTallSurface(tester);
    final repository = _FakeComplaintRepository();
    final router = _router();
    await tester.pumpWidget(_app(repository: repository, router: router));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('report-problem-button')), findsOneWidget);
    expect(find.byKey(const Key('existing-report-section')), findsNothing);

    await tester.tap(find.byKey(const Key('report-problem-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('report-form')), findsOneWidget);

    await tester.tap(find.byKey(const Key('report-issue-WORK_QUALITY')));
    await tester.tap(find.byKey(const Key('report-issue-WARRANTY_REWORK')));
    await tester.pump();
    expect(find.byKey(const Key('report-other-field')), findsNothing);

    await tester.tap(find.byKey(const Key('submit-report-button')));
    await tester.pump();
    expect(find.byKey(const Key('report-success')), findsOneWidget);
    expect(repository.createCalls, 1);
    expect(repository.stored, isNotNull);
    expect(repository.stored!.bookingId, 'booking-1');
    expect(repository.stored!.reporterUserId, 'client-1');
    expect(repository.stored!.reportedWorkerProfileId, 'worker-1');
    expect(repository.stored!.source, 'APP_CUSTOMER');
    expect(repository.stored!.status, ComplaintStatus.open);
    expect(repository.stored!.issueTypes, {
      ComplaintIssueType.workQuality,
      ComplaintIssueType.warrantyRework,
    });

    await tester.pump(const Duration(milliseconds: 901));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('report-problem-button')), findsNothing);
    expect(find.byKey(const Key('existing-report-section')), findsOneWidget);
    expect(find.text('Your report'), findsOneWidget);
    expect(find.text('Pending'), findsOneWidget);

    router.go('/client/booking/booking-1');
    await tester.pumpAndSettle();
    expect(repository.createCalls, 1);
    expect(find.byKey(const Key('report-problem-button')), findsNothing);
  });

  testWidgets('OTHER is conditional, required, cleared, and persisted',
      (tester) async {
    await _useTallSurface(tester);
    final repository = _FakeComplaintRepository();
    final router = _router(initialLocation: '/client/booking/booking-1/report');
    await tester.pumpWidget(_app(repository: repository, router: router));
    await tester.pumpAndSettle();

    final submit = tester.widget<FilledButton>(
      find.byKey(const Key('submit-report-button')),
    );
    expect(submit.onPressed, isNull);

    await tester.tap(find.byKey(const Key('report-issue-OTHER')));
    await tester.pump();
    expect(find.byKey(const Key('report-other-field')), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('submit-report-button')))
          .onPressed,
      isNull,
    );

    await tester.enterText(
      find.byKey(const Key('report-other-field')),
      '  Paint was scratched  ',
    );
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('submit-report-button')))
          .onPressed,
      isNotNull,
    );
    await tester.tap(find.byKey(const Key('submit-report-button')));
    await tester.pump();
    expect(repository.stored!.otherText, 'Paint was scratched');
    expect(repository.createCalls, 1);

    // Drain the success screen's auto-return delay so no timer outlives the
    // widget tree.
    await tester.pump(const Duration(milliseconds: 901));
    await tester.pumpAndSettle();
  });

  testWidgets('duplicate 409 fetches existing report without generic failure',
      (tester) async {
    await _useTallSurface(tester);
    final repository = _FakeComplaintRepository(conflictOnCreate: true);
    final router = _router(initialLocation: '/client/booking/booking-1/report');
    await tester.pumpWidget(_app(repository: repository, router: router));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('report-issue-WORK_QUALITY')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('submit-report-button')));
    await tester.pump();

    expect(find.byKey(const Key('report-success')), findsOneWidget);
    expect(find.text('Something went wrong. Please try again.'), findsNothing);
    expect(repository.createCalls, 1);
    expect(repository.rows, 1);

    // Back on Booking Detail the conflict has resolved to the one existing
    // report - no second row, no create action.
    await tester.pump(const Duration(milliseconds: 901));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('existing-report-section')), findsOneWidget);
    expect(find.byKey(const Key('report-problem-button')), findsNothing);
    expect(repository.rows, 1);
    expect(repository.createCalls, 1);
  });

  testWidgets('reopening Booking Detail shows the same report, never a new button',
      (tester) async {
    final repository = _FakeComplaintRepository();
    repository.stored = _complaint();
    final router = _router();
    await tester.pumpWidget(_app(repository: repository, router: router));
    await tester.pumpAndSettle();

    // A booking that already carries a report opens straight into the
    // existing-report state - the create action never appears.
    expect(find.byKey(const Key('existing-report-section')), findsOneWidget);
    expect(find.byKey(const Key('report-problem-button')), findsNothing);
    expect(find.text('Your report'), findsOneWidget);
    expect(find.text('Pending'), findsOneWidget);
    expect(repository.createCalls, 0);

    // Navigate away and come back: same single complaint, still no button.
    router.go('/client/booking/booking-1/report');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('report-already-submitted')), findsOneWidget);
    expect(find.byKey(const Key('report-form')), findsNothing);

    router.go('/client/booking/booking-1');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('existing-report-section')), findsOneWidget);
    expect(find.byKey(const Key('report-problem-button')), findsNothing);
    expect(repository.rows, 1);
    expect(repository.createCalls, 0);
  });

  test('report action is absent for every non-completed booking status', () {
    for (final status in BookingStatus.values) {
      final visible = shouldShowReportCreateAction(
        bookingStatus: status,
        isClient: true,
        ownsBooking: true,
        complaintState: const AsyncData(null),
      );
      expect(visible, status == BookingStatus.completed, reason: status.name);
    }
    expect(
      shouldShowReportCreateAction(
        bookingStatus: BookingStatus.completed,
        isClient: false,
        ownsBooking: true,
        complaintState: const AsyncData(null),
      ),
      isFalse,
    );
    expect(
      shouldShowReportCreateAction(
        bookingStatus: BookingStatus.completed,
        isClient: true,
        ownsBooking: false,
        complaintState: const AsyncData(null),
      ),
      isFalse,
    );
    expect(
      shouldShowReportCreateAction(
        bookingStatus: BookingStatus.completed,
        isClient: true,
        ownsBooking: true,
        complaintState: const AsyncLoading(),
      ),
      isFalse,
    );
  });

  testWidgets('all complaint statuses use the locked client labels',
      (tester) async {
    for (final entry in <ComplaintStatus, String>{
      ComplaintStatus.open: 'Pending',
      ComplaintStatus.inProgress: 'Under review',
      ComplaintStatus.waitingOnCustomer: 'Under review',
      ComplaintStatus.resolved: 'Resolved',
      ComplaintStatus.closed: 'Resolved',
    }.entries) {
      await tester.pumpWidget(_widgetApp(ComplaintStatusChip(status: entry.key)));
      expect(find.text(entry.value), findsOneWidget, reason: entry.key.name);
    }
  });

  testWidgets('report form and existing section fit target widths in both themes',
      (tester) async {
    for (final brightness in Brightness.values) {
      for (final width in [320.0, 360.0, 390.0, 430.0, 600.0]) {
        await tester.binding.setSurfaceSize(Size(width, 800));
        final repository = _FakeComplaintRepository();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [complaintRepositoryProvider.overrideWithValue(repository)],
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              darkTheme: AppTheme.darkTheme,
              themeMode: brightness == Brightness.dark
                  ? ThemeMode.dark
                  : ThemeMode.light,
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: AppLocalizations.supportedLocales,
              home: const ReportProblemPage(bookingId: 'booking-1'),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull,
            reason: '$brightness at ${width.toInt()}');

        repository.stored = _complaint();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [complaintRepositoryProvider.overrideWithValue(repository)],
            child: _widgetApp(
              const BookingComplaintSection(
                bookingId: 'booking-1',
                bookingStatus: BookingStatus.completed,
                isClient: true,
                ownsBooking: true,
              ),
              brightness: brightness,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull,
            reason: 'section $brightness at ${width.toInt()}');
      }
    }
    await tester.binding.setSurfaceSize(null);
  });
}

Widget _app({required _FakeComplaintRepository repository, required GoRouter router}) {
  return ProviderScope(
    overrides: [complaintRepositoryProvider.overrideWithValue(repository)],
    child: MaterialApp.router(
      routerConfig: router,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  );
}

Widget _widgetApp(Widget child, {Brightness brightness = Brightness.light}) {
  return MaterialApp(
    theme: AppTheme.lightTheme,
    darkTheme: AppTheme.darkTheme,
    themeMode: brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );
}

GoRouter _router({String initialLocation = '/client/booking/booking-1'}) {
  return GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/client/booking/:id',
        builder: (_, state) => Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: BookingComplaintSection(
              bookingId: state.pathParameters['id']!,
              bookingStatus: BookingStatus.completed,
              isClient: true,
              ownsBooking: true,
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/client/booking/:id/report',
        builder: (_, state) =>
            ReportProblemPage(bookingId: state.pathParameters['id']!),
      ),
    ],
  );
}

ComplaintEntity _complaint({
  Set<ComplaintIssueType> issues = const {ComplaintIssueType.workQuality},
  String? otherText,
}) {
  return ComplaintEntity(
    id: 'complaint-1',
    bookingId: 'booking-1',
    reporterUserId: 'client-1',
    reportedWorkerProfileId: 'worker-1',
    issueTypes: issues.toList(),
    otherText: otherText,
    source: 'APP_CUSTOMER',
    status: ComplaintStatus.open,
    humanRequested: false,
    createdAt: DateTime.utc(2026, 8, 27, 10),
    updatedAt: DateTime.utc(2026, 8, 27, 10),
  );
}

class _FakeComplaintRepository implements ComplaintRepository {
  _FakeComplaintRepository({this.conflictOnCreate = false});

  final bool conflictOnCreate;
  ComplaintEntity? stored;
  int createCalls = 0;
  bool _initialConflictLookupDone = false;

  int get rows => stored == null ? 0 : 1;

  @override
  Future<Either<Failure, ComplaintEntity?>> getForBooking(String bookingId) async {
    if (conflictOnCreate && !_initialConflictLookupDone) {
      _initialConflictLookupDone = true;
      return const Right(null);
    }
    return Right(stored);
  }

  @override
  Future<Either<Failure, ComplaintEntity>> createForBooking({
    required String bookingId,
    required Set<ComplaintIssueType> issueTypes,
    String? otherText,
  }) async {
    createCalls += 1;
    if (conflictOnCreate) {
      stored ??= _complaint(issues: issueTypes, otherText: otherText);
      return const Left(ConflictFailure(''));
    }
    stored ??= _complaint(issues: issueTypes, otherText: otherText);
    return Right(stored!);
  }

  @override
  Future<Either<Failure, ComplaintEntity>> requestHuman(
    String complaintId,
  ) async {
    stored = stored!.copyWith(
      humanRequested: true,
      humanRequestedAt: DateTime.utc(2026, 8, 27, 11),
    );
    return Right(stored!);
  }
}
