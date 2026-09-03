import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:go_router/go_router.dart';
import 'package:handygo_app/core/data/cached_result.dart';
import 'package:handygo_app/core/errors/failures.dart';
import 'package:handygo_app/core/l10n/app_locale.dart';
import 'package:handygo_app/core/l10n/locale_provider.dart';
import 'package:handygo_app/features/auth/presentation/pages/ustaad_register_step4_page.dart';
import 'package:handygo_app/features/auth/presentation/providers/ustaad_registration_draft.dart';
import 'package:handygo_app/features/worker/data/repositories/worker_repository_impl.dart';
import 'package:handygo_app/features/worker/domain/entities/agreement_template_entity.dart';
import 'package:handygo_app/features/worker/domain/entities/worker_profile_entity.dart';
import 'package:handygo_app/features/worker/domain/entities/worker_skill_entity.dart';
import 'package:handygo_app/features/worker/domain/entities/worker_stats_entity.dart';
import 'package:handygo_app/features/worker/domain/repositories/worker_repository.dart';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/l10n_test_app.dart';

/// Step 4 of Ustaad registration — the evidence the backend actually requires.
///
/// The bug: `submitProfileForReview` lists `liveSelfie` among its required
/// fields, and only `POST /workers/profile-completion/selfie` writes it. Step 3
/// uploads the customer-facing avatar through `PATCH /workers/avatar`, which
/// sets `avatarUrl` and nothing else. Step 4 never asked for a selfie at all,
/// so every submission was rejected with MISSING_PROFILE_DATA.

const _body = 'HandyGo Ustaad muahida. Tamam shurait parhna zaroori hai.';

AgreementTemplateEntity _template(String documentType, {String? trade}) =>
    AgreementTemplateEntity(
      documentType: documentType,
      title: 'Doc $documentType',
      version: '1.0',
      agreementLocale: 'ur_Latn',
      sourceHash: 'hash-$documentType',
      applicableTrade: trade,
      contentText: _body,
      legalLanguageNoticeRequired: false,
      requestedAppLocale: 'ur_Latn',
    );

List<AgreementTemplateEntity> _threeTemplates() => [
      _template(kUstaadGeneralAgreement),
      _template(kUstaadTradeAgreement, trade: 'ELECTRICIAN'),
      _template(kUstaadBackgroundEvsNotice),
    ];

WorkerProfileEntity _profile({
  String? cnicFrontUrl,
  String? cnicBackUrl,
  String? liveSelfieUrl,
}) =>
    WorkerProfileEntity(
      id: 'w1',
      userId: 'u1',
      firstName: 'Kamran',
      lastName: 'Sheikh',
      status: 'ACTIVE',
      verificationStatus: 'PENDING',
      availabilityStatus: AvailabilityStatus.offline,
      rating: 0,
      totalRatings: 0,
      skills: const [
        WorkerSkillEntity(
          id: 's1',
          categoryId: 'c1',
          categoryName: 'Electrician',
          yearsExperience: 3,
        ),
      ],
      stats: const WorkerStatsEntity(completedJobs: 0, activeJobs: 0),
      fullLegalName: 'Kamran Sheikh',
      fatherName: 'Sheikh Rafiq',
      dateOfBirth: '1995-04-02',
      residentialAddress: 'B-42, Street 14, Saddar',
      cnicNumber: '42101-1234567-1',
      cnicFrontUrl: cnicFrontUrl,
      cnicBackUrl: cnicBackUrl,
      liveSelfieUrl: liveSelfieUrl,
      legalNameConfirmedAt: DateTime(2026, 1, 1),
      onboardingStatus: 'DRAFT',
    );

class _FakeWorkerRepository implements WorkerRepository {
  _FakeWorkerRepository({required this.profile});

  WorkerProfileEntity profile;
  int submitCalls = 0;
  List<AgreementEvidence>? lastAgreements;

  @override
  Future<Either<Failure, CachedResult<WorkerProfileEntity>>> getProfile() async =>
      Right(CachedResult(profile));

  @override
  Future<Either<Failure, List<AgreementTemplateEntity>>> getAgreementTemplates({
    required String appLocale,
  }) async =>
      Right(_threeTemplates());

  @override
  Future<Either<Failure, List<AcceptedAgreementEntity>>> submitProfileForReview({
    required String submissionAttemptId,
    required List<AgreementEvidence> agreements,
  }) async {
    submitCalls++;
    lastAgreements = agreements;
    // What the backend answers with once `_missingProfileFields` is empty and
    // every agreement validated: sealed records, profile SUBMITTED_FOR_REVIEW.
    profile = _profile(
      cnicFrontUrl: profile.cnicFrontUrl,
      cnicBackUrl: profile.cnicBackUrl,
      liveSelfieUrl: profile.liveSelfieUrl,
    );
    return Right([
      for (final e in agreements)
        AcceptedAgreementEntity(
          id: 'acc-${e.documentType}',
          acceptanceId: 'acc-${e.documentType}',
          documentType: e.documentType,
          title: 'Doc ${e.documentType}',
          version: e.version,
          agreementLocale: e.agreementLocale,
          applicableTrade: null,
          acceptedAt: DateTime(2026, 2, 2),
        ),
    ]);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

late ProviderContainer _container;

/// `agreementTemplatesProvider` resolves the document language through
/// `localeProvider`, which is backed by SharedPreferences — without this the
/// three agreements never load and every "is Submit blocked" assertion passes
/// for the wrong reason.
Future<SharedPreferences> _prefs() async {
  SharedPreferences.setMockInitialValues({
    kLocalePrefsKey: AppLocale.romanUrdu.storageValue,
  });
  return SharedPreferences.getInstance();
}

Widget _app(_FakeWorkerRepository repo, SharedPreferences prefs) {
  final router = GoRouter(
    initialLocation: UstaadRegisterStep4Page.route,
    routes: [
      GoRoute(
        path: UstaadRegisterStep4Page.route,
        builder: (_, _) => const UstaadRegisterStep4Page(),
      ),
      GoRoute(
        path: '/worker/home',
        builder: (_, _) => const Scaffold(body: Text('WORKER_HOME')),
      ),
    ],
  );

  _container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      workerRepositoryProvider.overrideWithValue(repo),
    ],
  );
  addTearDown(_container.dispose);
  // Whatever Steps 1–3 left behind, so the "the draft is cleared" assertion is
  // about something.
  _container.read(ustaadRegistrationDraftProvider.notifier).update(
        (d) => d.copyWith(
          fullName: 'Kamran Sheikh',
          password: 'password123',
          accountCreated: true,
        ),
      );

  return UncontrolledProviderScope(
    container: _container,
    child: localizedRouterApp(router, locale: AppLocale.romanUrdu),
  );
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

/// Ticks one agreement box directly, without opening its document first.
Future<void> _tickAgreement(WidgetTester tester, int index) async {
  final box = find.byType(Checkbox).at(index);
  await tester.ensureVisible(box);
  await _settle(tester);
  await tester.tap(box);
  await _settle(tester);
}

/// Opens one document in the viewer and comes back.
///
/// The viewer is the single exit point: its own back arrow is what hands the
/// evidence back. It is a plain IconButton, not a Material BackButton.
Future<void> _openAndClose(WidgetTester tester, int index) async {
  final read = find.textContaining('Parhein').at(index);
  await tester.ensureVisible(read);
  await _settle(tester);
  await tester.tap(read);
  await tester.pumpAndSettle();
  expect(
    find.text(_body),
    findsOneWidget,
    reason: 'the approved legal body is still readable on request',
  );
  await tester.tap(find.byIcon(Icons.arrow_back));
  await tester.pumpAndSettle();
}

/// Accepts all three WITHOUT opening any of them — the locked behaviour.
Future<void> _acceptAll(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await _tickAgreement(tester, i);
  }
}

void main() {
  testWidgets('with the selfie, both CNIC sides and all three agreements, '
      'Submit reaches the backend and lands on Worker Home', (tester) async {
    tester.view.physicalSize = const Size(390, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final repo = _FakeWorkerRepository(
      profile: _profile(
        cnicFrontUrl: 'https://cdn/f.jpg',
        cnicBackUrl: 'https://cdn/b.jpg',
        liveSelfieUrl: 'https://cdn/s.jpg',
      ),
    );
    await tester.pumpWidget(_app(repo, await _prefs()));
    await _settle(tester);

    await _acceptAll(tester);

    final cta = find.widgetWithText(
      ElevatedButton,
      'Verification ke liye bhejein',
    );
    expect(
      tester.widget<ElevatedButton>(cta).onPressed,
      isNotNull,
      reason: 'everything the backend asks for is now present',
    );
    await tester.ensureVisible(cta);
    await _settle(tester);
    await tester.tap(cta);
    await tester.pumpAndSettle();

    expect(repo.submitCalls, 1);
    expect(
      repo.lastAgreements!.length,
      3,
      reason: 'one sealed evidence record per document the backend served',
    );
    for (final evidence in repo.lastAgreements!) {
      expect(evidence.checkboxAccepted, isTrue);
      // Nothing was opened, so nothing claims to have been read. The
      // acceptance is still fully identified by the document it names.
      expect(
        evidence.viewedAt,
        isNull,
        reason: 'an unopened document must not carry an invented viewedAt',
      );
      expect(evidence.version, '1.0');
      expect(evidence.sourceHash, 'hash-${evidence.documentType}');
    }
    expect(
      find.text('WORKER_HOME'),
      findsOneWidget,
      reason: 'SUBMITTED_FOR_REVIEW, then Worker Home — never auto-approved',
    );

    final draft = _container.read(ustaadRegistrationDraftProvider);
    expect(
      draft.password,
      isEmpty,
      reason: 'the draft — password and registration token — dies with the flow',
    );
    expect(draft.accountCreated, isFalse);
    expect(draft.fullName, isEmpty);
  });

  testWidgets('Submit is blocked until the LIVE SELFIE exists, even with both '
      'CNIC sides uploaded', (tester) async {
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final repo = _FakeWorkerRepository(
      profile: _profile(
        cnicFrontUrl: 'https://cdn/f.jpg',
        cnicBackUrl: 'https://cdn/b.jpg',
        // No selfie.
      ),
    );
    await tester.pumpWidget(_app(repo, await _prefs()));
    await _settle(tester);

    expect(
      find.text('Live selfie'),
      findsOneWidget,
      reason: 'the selfie card must exist — it did not before',
    );

    final cta = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Verification ke liye bhejein'),
    );
    expect(
      cta.onPressed,
      isNull,
      reason: 'the backend refuses this submission, so the app must not send '
          'it — Submit stayed enabled and every submission was rejected',
    );
    expect(repo.submitCalls, 0);
  });

  testWidgets('Submit is blocked with a CNIC side missing', (tester) async {
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final repo = _FakeWorkerRepository(
      profile: _profile(
        cnicFrontUrl: 'https://cdn/f.jpg',
        liveSelfieUrl: 'https://cdn/s.jpg',
        // No back.
      ),
    );
    await tester.pumpWidget(_app(repo, await _prefs()));
    await _settle(tester);

    final cta = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Verification ke liye bhejein'),
    );
    expect(cta.onPressed, isNull);
    expect(repo.submitCalls, 0);
  });

  testWidgets('Submit is blocked while an agreement is unticked, even with '
      'every document uploaded', (tester) async {
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final repo = _FakeWorkerRepository(
      profile: _profile(
        cnicFrontUrl: 'https://cdn/f.jpg',
        cnicBackUrl: 'https://cdn/b.jpg',
        liveSelfieUrl: 'https://cdn/s.jpg',
      ),
    );
    await tester.pumpWidget(_app(repo, await _prefs()));
    await _settle(tester);

    expect(
      find.byType(Checkbox),
      findsNWidgets(3),
      reason: 'the three documents must actually have loaded, or this test '
          'would pass over an empty list',
    );
    // Nothing is ticked for the Ustaad: every box starts empty.
    for (final checkbox in tester.widgetList<Checkbox>(find.byType(Checkbox))) {
      expect(checkbox.value, isFalse);
    }

    // Two of three accepted — the third still blocks Submit.
    await _tickAgreement(tester, 0);
    await _tickAgreement(tester, 1);

    final cta = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Verification ke liye bhejein'),
    );
    expect(
      cta.onPressed,
      isNull,
      reason: 'acceptance of every required agreement is still mandatory',
    );
    expect(repo.submitCalls, 0);
  });

  testWidgets('on a fresh page every agreement box is enabled and can be '
      'ticked without opening the document first', (tester) async {
    tester.view.physicalSize = const Size(390, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final repo = _FakeWorkerRepository(
      profile: _profile(
        cnicFrontUrl: 'https://cdn/f.jpg',
        cnicBackUrl: 'https://cdn/b.jpg',
        liveSelfieUrl: 'https://cdn/s.jpg',
      ),
    );
    await tester.pumpWidget(_app(repo, await _prefs()));
    await _settle(tester);

    expect(find.byType(Checkbox), findsNWidgets(3));
    for (final checkbox in tester.widgetList<Checkbox>(find.byType(Checkbox))) {
      expect(
        checkbox.onChanged,
        isNotNull,
        reason: 'nothing was opened, and ticking is still the Ustaad own '
            'act — reading is offered, never demanded',
      );
      expect(checkbox.value, isFalse, reason: 'and nothing is pre-ticked');
    }

    // A direct tick, no viewer in between.
    await _tickAgreement(tester, 0);
    expect(
      tester.widgetList<Checkbox>(find.byType(Checkbox)).first.value,
      isTrue,
    );
  });

  testWidgets('the document is still openable, and reading it after ticking '
      'keeps the acceptance and seals the real viewedAt', (tester) async {
    tester.view.physicalSize = const Size(390, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final repo = _FakeWorkerRepository(
      profile: _profile(
        cnicFrontUrl: 'https://cdn/f.jpg',
        cnicBackUrl: 'https://cdn/b.jpg',
        liveSelfieUrl: 'https://cdn/s.jpg',
      ),
    );
    await tester.pumpWidget(_app(repo, await _prefs()));
    await _settle(tester);

    // Tick first, read afterwards — the viewer must not undo the tick.
    await _tickAgreement(tester, 0);
    await _openAndClose(tester, 0);
    expect(
      tester.widgetList<Checkbox>(find.byType(Checkbox)).first.value,
      isTrue,
      reason: 'opening the document the Ustaad already accepted cannot '
          'silently drop that acceptance',
    );

    await _tickAgreement(tester, 1);
    await _tickAgreement(tester, 2);

    final cta = find.widgetWithText(
      ElevatedButton,
      'Verification ke liye bhejein',
    );
    await tester.ensureVisible(cta);
    await _settle(tester);
    await tester.tap(cta);
    await tester.pumpAndSettle();

    expect(repo.submitCalls, 1);
    expect(repo.lastAgreements!.length, 3);
    // The electronic acceptance record keeps its shape: the document's own
    // identity and the explicit tick, on every row.
    for (final evidence in repo.lastAgreements!) {
      expect(evidence.checkboxAccepted, isTrue);
      expect(evidence.version, '1.0');
      expect(evidence.agreementLocale, 'ur_Latn');
      expect(evidence.sourceHash, 'hash-${evidence.documentType}');
    }

    // viewedAt is per-document and truthful: only the one that was actually
    // opened carries a timestamp.
    final opened = repo.lastAgreements!
        .firstWhere((e) => e.documentType == kUstaadGeneralAgreement);
    expect(opened.viewedAt, isNotNull, reason: 'this one was really rendered');
    expect(opened.wasViewed, isTrue);
    for (final evidence in repo.lastAgreements!
        .where((e) => e.documentType != kUstaadGeneralAgreement)) {
      expect(
        evidence.viewedAt,
        isNull,
        reason: 'these two were accepted without ever being opened',
      );
      expect(evidence.wasViewed, isFalse);
    }
  });

  testWidgets('the evidence sent for an unopened agreement carries no '
      'viewedAt on the wire either', (tester) async {
    tester.view.physicalSize = const Size(390, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final repo = _FakeWorkerRepository(
      profile: _profile(
        cnicFrontUrl: 'https://cdn/f.jpg',
        cnicBackUrl: 'https://cdn/b.jpg',
        liveSelfieUrl: 'https://cdn/s.jpg',
      ),
    );
    await tester.pumpWidget(_app(repo, await _prefs()));
    await _settle(tester);

    await _openAndClose(tester, 0);
    await _acceptAll(tester);

    final cta = find.widgetWithText(
      ElevatedButton,
      'Verification ke liye bhejein',
    );
    await tester.ensureVisible(cta);
    await _settle(tester);
    await tester.tap(cta);
    await tester.pumpAndSettle();

    // What actually reaches POST /workers/profile-completion/submit.
    final json = {
      for (final e in repo.lastAgreements!) e.documentType: e.toJson(),
    };
    expect(
      json[kUstaadGeneralAgreement]!['viewedAt'],
      isA<String>(),
      reason: 'opened — a real ISO timestamp the backend may seal',
    );
    expect(
      json[kUstaadTradeAgreement]!['viewedAt'],
      isNull,
      reason: 'never opened — the field is null, not a fabricated now()',
    );
    expect(
      json[kUstaadBackgroundEvsNotice]!['viewedAt'],
      isNull,
    );
    // The rest of the evidence is unchanged by any of this.
    for (final row in json.values) {
      expect(row['checkboxAccepted'], isTrue);
      expect(row['version'], '1.0');
      expect(row['agreementLocale'], 'ur_Latn');
      expect(row['sourceHash'], isNotNull);
    }
  });

  testWidgets('the three evidence tiles are selfie, CNIC front and CNIC back, '
      'and each reports its own state', (tester) async {
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final repo = _FakeWorkerRepository(
      profile: _profile(
        cnicFrontUrl: 'https://cdn/f.jpg',
        liveSelfieUrl: 'https://cdn/s.jpg',
      ),
    );
    await tester.pumpWidget(_app(repo, await _prefs()));
    await _settle(tester);

    expect(find.text('Live selfie'), findsOneWidget);
    expect(find.text('CNIC front'), findsOneWidget);
    expect(find.text('CNIC back'), findsOneWidget);
    // Selfie + front uploaded, back still pending.
    expect(find.text('Lag gaya'), findsNWidgets(2));
    expect(find.text('Baqi hai'), findsOneWidget);
  });
}
