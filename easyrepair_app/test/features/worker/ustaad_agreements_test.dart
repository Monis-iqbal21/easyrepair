import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:handygo_app/core/data/cached_result.dart';
import 'package:handygo_app/core/errors/failures.dart';
import 'package:handygo_app/core/l10n/app_locale.dart';
import 'package:handygo_app/core/l10n/locale_provider.dart';
import 'package:handygo_app/features/worker/data/repositories/worker_repository_impl.dart';
import 'package:handygo_app/features/worker/domain/entities/agreement_template_entity.dart';
import 'package:handygo_app/features/worker/domain/entities/worker_profile_entity.dart';
import 'package:handygo_app/features/worker/domain/entities/worker_skill_entity.dart';
import 'package:handygo_app/features/worker/domain/entities/worker_stats_entity.dart';
import 'package:handygo_app/features/worker/domain/repositories/worker_repository.dart';
import 'package:handygo_app/features/worker/presentation/pages/agreement_viewer_page.dart';
import 'package:handygo_app/features/worker/presentation/pages/worker_agreements_page.dart';
import 'package:handygo_app/features/worker/presentation/pages/worker_profile_completion_page.dart';
import 'package:handygo_app/features/worker/presentation/providers/worker_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/l10n_test_app.dart';

/// The reachable Ustaad agreement flow, from the app's side.
///
/// These tests exist because the alternative is a legal defect: a fourth
/// (Customer) document appearing on the Ustaad's screen, a checkbox that can
/// be ticked without the document ever being opened, or a trade change that
/// silently carries the previous trade's acceptance forward.

// ── Fakes ───────────────────────────────────────────────────────────────────

const _kRomanUrduBody = '''
HANDYGO USTAAD SERVICE PROVIDER AGREEMENT

1. TAARUF
Yeh muahida HandyGo aur Ustaad ke darmiyan hai. Ustaad ko yeh tamam
shurait parhna aur samajhna zaroori hai. Muahide ki tamam dafaat lagoo hongi
aur inhe qabool karne ke baad hi Ustaad kaam shuru kar sakta hai.
''';

AgreementTemplateEntity _template({
  required String documentType,
  String? trade,
  String version = '1.0',
  String sourceHash = 'hash-general',
  bool noticeRequired = false,
  String requestedAppLocale = 'en',
}) {
  return AgreementTemplateEntity(
    documentType: documentType,
    title: switch (documentType) {
      kUstaadGeneralAgreement => 'HandyGo Ustaad Service Provider Agreement',
      kUstaadTradeAgreement => 'HandyGo Trade-Specific Service Agreement',
      _ => 'HandyGo Background Verification, EVS Consent aur Ustaad Privacy Notice',
    },
    version: version,
    agreementLocale: 'ur_Latn',
    sourceHash: sourceHash,
    applicableTrade: trade,
    contentText: _kRomanUrduBody,
    legalLanguageNoticeRequired: noticeRequired,
    requestedAppLocale: requestedAppLocale,
  );
}

List<AgreementTemplateEntity> _threeTemplates({
  String trade = 'ELECTRICIAN',
  bool noticeRequired = false,
}) =>
    [
      _template(
        documentType: kUstaadGeneralAgreement,
        noticeRequired: noticeRequired,
      ),
      _template(
        documentType: kUstaadTradeAgreement,
        trade: trade,
        sourceHash: 'hash-trade-$trade',
        noticeRequired: noticeRequired,
      ),
      _template(
        documentType: kUstaadBackgroundEvsNotice,
        sourceHash: 'hash-evs',
        noticeRequired: noticeRequired,
      ),
    ];

WorkerProfileEntity _profile({
  String? fatherName,
  String? dateOfBirth,
  String skill = 'Electrician',
}) {
  return WorkerProfileEntity(
    id: 'worker-1',
    userId: 'user-1',
    firstName: 'Ali',
    lastName: 'Khan',
    status: 'ACTIVE',
    verificationStatus: 'PENDING',
    availabilityStatus: AvailabilityStatus.offline,
    rating: 0,
    totalRatings: 0,
    skills: [
      WorkerSkillEntity(
        id: 'skill-1',
        categoryId: 'cat-1',
        categoryName: skill,
        yearsExperience: 5,
      ),
    ],
    stats: const WorkerStatsEntity(completedJobs: 0, activeJobs: 0),
    fullLegalName: 'Muhammad Ali Khan',
    fatherName: fatherName,
    dateOfBirth: dateOfBirth,
    residentialAddress: 'House 12, Karachi',
    cnicNumber: '42101-1234567-1',
    cnicFrontUrl: 'https://cdn/f.jpg',
    cnicBackUrl: 'https://cdn/b.jpg',
    liveSelfieUrl: 'https://cdn/s.jpg',
    onboardingStatus: 'DRAFT',
  );
}

/// Records every call the UI makes, so a test can assert on what was actually
/// sent rather than on what the widget tree looks like afterwards.
class FakeWorkerRepository implements WorkerRepository {
  FakeWorkerRepository({
    WorkerProfileEntity? profile,
    List<AgreementTemplateEntity>? templates,
    this.templatesFail = false,
    this.accepted = const [],
  })  : profile = profile ?? _profile(),
        templates = templates ?? _threeTemplates();

  WorkerProfileEntity profile;
  List<AgreementTemplateEntity> templates;
  bool templatesFail;
  List<AcceptedAgreementEntity> accepted;

  String? lastAppLocale;
  String? lastSubmissionAttemptId;
  List<AgreementEvidence>? lastAgreements;
  Map<String, dynamic>? lastSavedFields;
  String? lastDownloadedAcceptanceId;

  @override
  Future<Either<Failure, CachedResult<WorkerProfileEntity>>> getProfile() async =>
      Right(CachedResult(profile));

  @override
  Future<Either<Failure, List<AgreementTemplateEntity>>> getAgreementTemplates({
    required String appLocale,
  }) async {
    lastAppLocale = appLocale;
    if (templatesFail) {
      return const Left(ServerFailure('boom'));
    }
    return Right(templates);
  }

  @override
  Future<Either<Failure, List<AcceptedAgreementEntity>>> getMyAgreements() async =>
      Right(accepted);

  @override
  Future<Either<Failure, List<int>>> downloadAgreementPdf(
    String acceptanceId,
  ) async {
    lastDownloadedAcceptanceId = acceptanceId;
    return const Right([37, 80, 68, 70]); // %PDF
  }

  @override
  Future<Either<Failure, void>> updateProfileCompletion({
    String? fullLegalName,
    String? residentialAddress,
    String? cnicNumber,
    String? fatherName,
    String? dateOfBirth,
    String? emergencyContact,
    int? experienceYears,
    bool? legalNameConfirmed,
  }) async {
    lastSavedFields = {
      'fullLegalName': fullLegalName,
      'fatherName': fatherName,
      'dateOfBirth': dateOfBirth,
      'emergencyContact': emergencyContact,
    };
    return const Right(null);
  }

  @override
  Future<Either<Failure, List<AcceptedAgreementEntity>>> submitProfileForReview({
    required String submissionAttemptId,
    required List<AgreementEvidence> agreements,
  }) async {
    lastSubmissionAttemptId = submissionAttemptId;
    lastAgreements = agreements;
    return Right(accepted);
  }

  // Everything below is outside these tests; a call would be a bug worth
  // failing loudly on rather than silently returning a default.
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not stubbed');
}

// ── Harness ─────────────────────────────────────────────────────────────────

/// A 1x1 transparent PNG, served for every network image.
///
/// The profile form renders the uploaded CNIC/selfie thumbnails with
/// `Image.network`, and the test binding fails every real request with a 400
/// that surfaces as an unexpected exception. Serving real bytes keeps these
/// tests about agreements rather than about image loading.
const _kTransparentPng = <int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, //
  0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
  0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41,
  0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
  0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
  0x42, 0x60, 0x82,
];

class _StubImageHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) => _StubHttpClient();
}

class _StubHttpClient implements HttpClient {
  @override
  bool autoUncompress = true;

  @override
  Future<HttpClientRequest> getUrl(Uri url) async => _StubHttpClientRequest();

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _StubHttpClientRequest implements HttpClientRequest {
  @override
  HttpHeaders get headers => _StubHttpHeaders();

  @override
  Future<HttpClientResponse> close() async => _StubHttpClientResponse();

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _StubHttpClientResponse implements HttpClientResponse {
  @override
  int get statusCode => 200;

  @override
  int get contentLength => _kTransparentPng.length;

  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream<List<int>>.fromIterable([_kTransparentPng]).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _StubHttpHeaders implements HttpHeaders {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

Future<void> _pump(
  WidgetTester tester,
  FakeWorkerRepository repo, {
  Widget? home,
  AppLocale locale = AppLocale.english,
}) async {
  // A phone-shaped but tall surface, so the long profile form is reachable
  // without every assertion having to scroll first.
  tester.view.physicalSize = const Size(1080, 3200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  SharedPreferences.setMockInitialValues({
    kLocalePrefsKey: locale.storageValue,
  });
  final prefs = await SharedPreferences.getInstance();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        workerRepositoryProvider.overrideWithValue(repo),
      ],
      child: localizedApp(
        home ?? const WorkerProfileCompletionPage(),
        locale: locale,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _agreementRowFor(String title) => find.text(title);

/// The checkbox inside the card that shows [title].
Checkbox _checkboxIn(WidgetTester tester, String title) {
  final card = find.ancestor(
    of: find.text(title),
    matching: find.byType(Container),
  );
  return tester.widget<Checkbox>(
    find
        .descendant(of: card.first, matching: find.byType(Checkbox))
        .first,
  );
}

/// Scrolls [finder] into view and taps it, so an assertion never fails merely
/// because the long form pushed a control below the fold.
Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// Leaves the agreement viewer the way a user does — its AppBar arrow, which
/// is what hands the captured evidence back to the form.
Future<void> _back(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.arrow_back));
  await tester.pumpAndSettle();
}

/// Opens the agreement whose "View Agreement" link is at [index], lets it
/// render, and comes back.
Future<void> _viewAgreementAt(WidgetTester tester, int index) async {
  await _tap(tester, find.text('View Agreement').at(index));
  await _back(tester);
}

/// The checkbox belonging to the agreement card titled [title].
Finder _checkboxFinderIn(String title) => find
    .descendant(
      of: find
          .ancestor(of: find.text(title), matching: find.byType(Container))
          .first,
      matching: find.byType(Checkbox),
    )
    .first;

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    // Serve real bytes for the CNIC/selfie thumbnails; see _kTransparentPng.
    HttpOverrides.global = _StubImageHttpOverrides();

    // The download writes the PDF to the app documents directory and then
    // hands it to whatever can open a PDF. Both are platform channels with no
    // implementation under flutter_test, so they are stubbed here rather than
    // left to throw inside the widget under test.
    final messenger = binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => Directory.systemTemp.createTempSync('handygo').path,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/url_launcher'),
      (call) async => true,
    );
  });

  tearDownAll(() => HttpOverrides.global = null);

  group('required identity fields', () {
    testWidgets('the profile form asks for father\'s name', (tester) async {
      await _pump(tester, FakeWorkerRepository());
      expect(find.text("Father's Name"), findsOneWidget);
    });

    testWidgets('the profile form asks for date of birth', (tester) async {
      await _pump(tester, FakeWorkerRepository());
      expect(find.text('Date of Birth'), findsOneWidget);
      expect(find.text('Select your date of birth'), findsOneWidget);
    });

    testWidgets('a saved father\'s name and DOB are pre-filled, not re-asked',
        (tester) async {
      await _pump(
        tester,
        FakeWorkerRepository(
          profile: _profile(
            fatherName: 'Abdul Rehman Khan',
            dateOfBirth: '1990-04-12',
          ),
        ),
      );

      expect(find.text('Abdul Rehman Khan'), findsOneWidget);
      expect(find.text('1990-04-12'), findsOneWidget);
    });

    testWidgets('submitting without father\'s name and DOB is blocked',
        (tester) async {
      final repo = FakeWorkerRepository();
      await _pump(tester, repo);

      await _tap(tester, find.text('Submit for Approval'));

      expect(repo.lastAgreements, isNull);
      expect(find.text("Father's name is required."), findsOneWidget);
      expect(find.text('Date of birth is required.'), findsOneWidget);
    });
  });

  group('exactly three agreement rows', () {
    testWidgets('all three documents are shown', (tester) async {
      await _pump(tester, FakeWorkerRepository());

      expect(
        _agreementRowFor('HandyGo Ustaad Service Provider Agreement'),
        findsOneWidget,
      );
      expect(
        _agreementRowFor('HandyGo Trade-Specific Service Agreement'),
        findsOneWidget,
      );
      expect(
        _agreementRowFor(
          'HandyGo Background Verification, EVS Consent aur Ustaad Privacy Notice',
        ),
        findsOneWidget,
      );
    });

    testWidgets('the Customer agreement never appears', (tester) async {
      await _pump(tester, FakeWorkerRepository());

      expect(find.textContaining('Customer Terms'), findsNothing);
      expect(find.textContaining('Customer'), findsNothing);
    });

    testWidgets('each row shows version, language and the required marker',
        (tester) async {
      await _pump(tester, FakeWorkerRepository());

      expect(find.text('Version 1.0'), findsNWidgets(3));
      // Roman Urdu is the language of the approved legal body.
      expect(find.text('Agreement Language: Roman Urdu'), findsNWidgets(3));
      expect(find.text('Required'), findsNWidgets(3));
      // Only the trade document carries a trade.
      expect(find.text('Trade: Electrician'), findsOneWidget);
    });
  });

  group('accepting a document', () {
    testWidgets('every checkbox starts unchecked but is tickable', (tester) async {
      await _pump(tester, FakeWorkerRepository());

      for (final title in const [
        'HandyGo Ustaad Service Provider Agreement',
        'HandyGo Trade-Specific Service Agreement',
        'HandyGo Background Verification, EVS Consent aur Ustaad Privacy Notice',
      ]) {
        final box = _checkboxIn(tester, title);
        expect(box.value, isFalse, reason: '$title started checked');
        // Reading is offered, never enforced.
        expect(box.onChanged, isNotNull, reason: '$title was not tickable');
      }
      expect(
        find.text('Open and read the agreement before accepting it.'),
        findsNothing,
      );
    });

    testWidgets('a box can be ticked without ever opening the viewer',
        (tester) async {
      final repo = FakeWorkerRepository();
      await _pump(tester, repo);

      await _tap(
        tester,
        _checkboxFinderIn('HandyGo Ustaad Service Provider Agreement'),
      );

      expect(
        _checkboxIn(tester, 'HandyGo Ustaad Service Provider Agreement').value,
        isTrue,
      );
      // Ticking one row leaves the others alone.
      expect(
        _checkboxIn(tester, 'HandyGo Trade-Specific Service Agreement').value,
        isFalse,
      );
      expect(find.byType(AgreementViewerPage), findsNothing);
    });

    testWidgets('the viewer stays reachable and does not tick anything',
        (tester) async {
      await _pump(tester, FakeWorkerRepository());

      await _tap(tester, find.text('View Agreement').first);
      expect(find.byType(AgreementViewerPage), findsOneWidget);
      await _back(tester);

      expect(
        _checkboxIn(tester, 'HandyGo Ustaad Service Provider Agreement').value,
        isFalse,
      );
    });

    testWidgets('coming back from the viewer keeps what was typed',
        (tester) async {
      await _pump(tester, FakeWorkerRepository());

      // Legal name and father's name share the "As written on your CNIC"
      // hint, and the father's field is the second of the two.
      await tester.enterText(
        find.widgetWithText(TextField, 'As written on your CNIC').at(1),
        'Abdul Rehman Khan',
      );
      await tester.pumpAndSettle();

      await _viewAgreementAt(tester, 0);

      // The form was never rebuilt from scratch, so the typed value survives.
      expect(find.text('Abdul Rehman Khan'), findsOneWidget);
    });

    testWidgets('an agreement that fails to load never counts as viewed',
        (tester) async {
      final repo = FakeWorkerRepository(templatesFail: true);
      await _pump(tester, repo);

      // No rows at all — just the error and a retry.
      expect(find.text('View Agreement'), findsNothing);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('the box must still be ticked by hand after viewing',
        (tester) async {
      await _pump(tester, FakeWorkerRepository());

      await _viewAgreementAt(tester, 0);

      expect(
        _checkboxIn(tester, 'HandyGo Ustaad Service Provider Agreement').value,
        isFalse,
      );
    });
  });

  group('the viewer', () {
    testWidgets('renders the full approved legal body verbatim',
        (tester) async {
      await _pump(
        tester,
        FakeWorkerRepository(),
        home: const AgreementViewerPage(
          documentType: kUstaadGeneralAgreement,
        ),
      );

      expect(find.textContaining('HANDYGO USTAAD SERVICE PROVIDER AGREEMENT'),
          findsWidgets);
      expect(find.textContaining('Muahide ki tamam dafaat lagoo hongi'),
          findsOneWidget);
    });

    testWidgets('always states that the agreement language is Roman Urdu',
        (tester) async {
      await _pump(
        tester,
        FakeWorkerRepository(),
        home: const AgreementViewerPage(
          documentType: kUstaadGeneralAgreement,
        ),
      );

      expect(find.text('Agreement Language: Roman Urdu'), findsOneWidget);
    });

    testWidgets('shows the English notice when the app is in English',
        (tester) async {
      await _pump(
        tester,
        FakeWorkerRepository(templates: _threeTemplates(noticeRequired: true)),
        home: const AgreementViewerPage(
          documentType: kUstaadGeneralAgreement,
        ),
      );

      expect(
        find.text(
          'This approved legal agreement is currently available in Roman Urdu.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('shows the Urdu notice when the app is in Urdu',
        (tester) async {
      await _pump(
        tester,
        FakeWorkerRepository(templates: _threeTemplates(noticeRequired: true)),
        home: const AgreementViewerPage(
          documentType: kUstaadGeneralAgreement,
        ),
        locale: AppLocale.urdu,
      );

      expect(
        find.text(
          'یہ منظور شدہ '
          'قانونی معاہدہ '
          'فی الحال صرف '
          'رومن اردو میں '
          'دستیاب ہے۔',
        ),
        findsOneWidget,
      );
    });

    testWidgets('drops the notice when the app is already in Roman Urdu',
        (tester) async {
      await _pump(
        tester,
        FakeWorkerRepository(),
        home: const AgreementViewerPage(
          documentType: kUstaadGeneralAgreement,
        ),
        locale: AppLocale.romanUrdu,
      );

      expect(
        find.textContaining('filhaal sirf Roman Urdu mein mojood hai'),
        findsNothing,
      );
    });

    testWidgets('stays left-to-right in Urdu', (tester) async {
      await _pump(
        tester,
        FakeWorkerRepository(),
        home: const AgreementViewerPage(
          documentType: kUstaadGeneralAgreement,
        ),
        locale: AppLocale.urdu,
      );

      final scaffold = tester.element(find.byType(Scaffold).first);
      expect(Directionality.of(scaffold), TextDirection.ltr);
    });

    testWidgets('requests the templates in the app\'s language',
        (tester) async {
      final repo = FakeWorkerRepository();
      await _pump(tester, repo, locale: AppLocale.urdu);
      expect(repo.lastAppLocale, 'ur');
    });
  });

  group('trade change', () {
    testWidgets('clears only the trade agreement, keeping the other two',
        (tester) async {
      final repo = FakeWorkerRepository();
      await _pump(tester, repo);

      // View and accept all three.
      for (var i = 0; i < 3; i++) {
        await _viewAgreementAt(tester, i);
      }
      for (final title in const [
        'HandyGo Ustaad Service Provider Agreement',
        'HandyGo Trade-Specific Service Agreement',
        'HandyGo Background Verification, EVS Consent aur Ustaad Privacy Notice',
      ]) {
        await _tap(tester, _checkboxFinderIn(title));
      }
      expect(
        _checkboxIn(tester, 'HandyGo Trade-Specific Service Agreement').value,
        isTrue,
      );

      // The Ustaad switches trade: a different schedule, so a different hash.
      repo.templates = _threeTemplates(trade: 'PLUMBER');
      repo.profile = _profile(
        fatherName: 'Abdul Rehman Khan',
        dateOfBirth: '1990-04-12',
        skill: 'Plumber',
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(WorkerProfileCompletionPage)),
      );
      container.invalidate(agreementTemplatesProvider);
      await tester.pumpAndSettle();

      // Only the trade row lost its acceptance.
      expect(
        _checkboxIn(tester, 'HandyGo Trade-Specific Service Agreement').value,
        isFalse,
      );
      expect(
        _checkboxIn(tester, 'HandyGo Trade-Specific Service Agreement').onChanged,
        isNotNull,
        reason: 'the new schedule must still be acceptable',
      );
      expect(
        _checkboxIn(tester, 'HandyGo Ustaad Service Provider Agreement').value,
        isTrue,
      );
      expect(
        _checkboxIn(
          tester,
          'HandyGo Background Verification, EVS Consent aur Ustaad Privacy Notice',
        ).value,
        isTrue,
      );
      expect(find.text('Trade: Plumber'), findsOneWidget);
    });
  });

  group('the list comes from the backend', () {
    /// Nothing in the app fixes how many documents there are. Whatever the
    /// template endpoint returns is what the Ustaad sees and must accept, so
    /// activating a further document is a backend change alone.
    testWidgets('renders every returned document, including a fourth',
        (tester) async {
      const kFourth = 'CODE_OF_CONDUCT';
      final repo = FakeWorkerRepository(
        profile: _profile(
          fatherName: 'Abdul Rehman Khan',
          dateOfBirth: '1990-04-12',
        ),
        templates: [
          ..._threeTemplates(),
          _template(documentType: kFourth, sourceHash: 'hash-conduct'),
        ],
      );
      await _pump(tester, repo);

      expect(find.text('View Agreement'), findsNWidgets(4));
      expect(find.text('Version 1.0'), findsNWidgets(4));

      // And all four must be accepted before submission is allowed.
      for (var i = 0; i < 3; i++) {
        await _tap(
          tester,
          _checkboxFinderIn(const [
            'HandyGo Ustaad Service Provider Agreement',
            'HandyGo Trade-Specific Service Agreement',
            'HandyGo Background Verification, EVS Consent aur Ustaad Privacy Notice',
          ][i]),
        );
      }
      await _tap(tester, find.byType(Checkbox).first); // legal-name confirm
      await _tap(tester, find.text('Submit for Approval'));

      // The fourth is still untouched, so nothing was sent.
      expect(repo.lastAgreements, isNull);
    });
  });

  group('unsupported trade', () {
    /// The backend refuses to resolve a schedule for an unmapped trade, so the
    /// trade template simply is not in the response. The form must block
    /// submission rather than fall back to another trade's schedule.
    testWidgets('blocks submission and never offers another schedule',
        (tester) async {
      final repo = FakeWorkerRepository(
        profile: _profile(
          fatherName: 'Abdul Rehman Khan',
          dateOfBirth: '1990-04-12',
          skill: 'Painter',
        ),
        templates: [
          _template(documentType: kUstaadGeneralAgreement),
          _template(documentType: kUstaadBackgroundEvsNotice,
              sourceHash: 'hash-evs'),
        ],
      );
      await _pump(tester, repo);

      expect(
        find.textContaining('No approved agreement is available'),
        findsOneWidget,
      );
      // No other trade's schedule was substituted.
      expect(find.textContaining('Trade: '), findsNothing);
      // Only the two available documents can be opened.
      expect(find.text('View Agreement'), findsNWidgets(2));

      for (var i = 0; i < 2; i++) {
        await _viewAgreementAt(tester, i);
      }
      for (final title in const [
        'HandyGo Ustaad Service Provider Agreement',
        'HandyGo Background Verification, EVS Consent aur Ustaad Privacy Notice',
      ]) {
        await _tap(tester, _checkboxFinderIn(title));
      }
      await _tap(tester, find.byType(Checkbox).first);

      await _tap(tester, find.text('Submit for Approval'));

      expect(repo.lastAgreements, isNull);
    });
  });

  group('submission', () {
    testWidgets('is blocked until all three agreements are accepted',
        (tester) async {
      final repo = FakeWorkerRepository(
        profile: _profile(
          fatherName: 'Abdul Rehman Khan',
          dateOfBirth: '1990-04-12',
        ),
      );
      await _pump(tester, repo);

      await _tap(tester, find.text('Submit for Approval'));

      expect(repo.lastAgreements, isNull);
      expect(find.text('This agreement must be accepted.'), findsNWidgets(3));
    });

    testWidgets('sends exactly three evidence objects and one attempt id',
        (tester) async {
      final repo = FakeWorkerRepository(
        profile: _profile(
          fatherName: 'Abdul Rehman Khan',
          dateOfBirth: '1990-04-12',
        ),
      );
      await _pump(tester, repo);

      for (var i = 0; i < 3; i++) {
        await _viewAgreementAt(tester, i);
      }
      for (final title in const [
        'HandyGo Ustaad Service Provider Agreement',
        'HandyGo Trade-Specific Service Agreement',
        'HandyGo Background Verification, EVS Consent aur Ustaad Privacy Notice',
      ]) {
        await _tap(tester, _checkboxFinderIn(title));
      }
      // "I confirm my legal name matches my CNIC."
      await _tap(tester, find.byType(Checkbox).first);

      await _tap(tester, find.text('Submit for Approval'));

      expect(repo.lastAgreements, isNotNull);
      expect(repo.lastAgreements!.length, 3);
      expect(
        repo.lastAgreements!.map((e) => e.documentType).toList(),
        kUstaadDocumentTypes,
      );
      expect(repo.lastAgreements!.every((e) => e.checkboxAccepted), isTrue);
      expect(
        repo.lastAgreements!.every((e) => e.agreementLocale == 'ur_Latn'),
        isTrue,
        reason: 'evidence must record the accepted language, not the app one',
      );
      expect(repo.lastSubmissionAttemptId, isNotNull);
      expect(repo.lastSubmissionAttemptId, isNotEmpty);

      // Identity was saved from the form, and the trade evidence carries the
      // trade the schedule belongs to.
      expect(repo.lastSavedFields!['fatherName'], 'Abdul Rehman Khan');
      expect(repo.lastSavedFields!['dateOfBirth'], '1990-04-12');
      expect(
        repo.lastAgreements!
            .firstWhere((e) => e.documentType == kUstaadTradeAgreement)
            .applicableTrade,
        'ELECTRICIAN',
      );
    });
  });

  group('Worker Legal section', () {
    testWidgets('lists the accepted agreements with view and download',
        (tester) async {
      final repo = FakeWorkerRepository(
        accepted: [
          AcceptedAgreementEntity(
            id: 'row-1',
            acceptanceId: 'HG-ACC-2026-AAAA',
            documentType: kUstaadGeneralAgreement,
            title: 'HandyGo Ustaad Service Provider Agreement',
            version: '1.0',
            agreementLocale: 'ur_Latn',
            applicableTrade: null,
            acceptedAt: DateTime.utc(2026, 8, 3, 9, 5),
          ),
          AcceptedAgreementEntity(
            id: 'row-2',
            acceptanceId: 'HG-ACC-2026-BBBB',
            documentType: kUstaadTradeAgreement,
            title: 'HandyGo Trade-Specific Service Agreement',
            version: '1.0',
            agreementLocale: 'ur_Latn',
            applicableTrade: 'ELECTRICIAN',
            acceptedAt: DateTime.utc(2026, 8, 3, 9, 5),
          ),
        ],
      );

      await _pump(tester, repo, home: const WorkerAgreementsPage());

      expect(
        find.text('HandyGo Ustaad Service Provider Agreement'),
        findsOneWidget,
      );
      expect(find.text('Agreement Language: Roman Urdu'), findsNWidgets(2));
      expect(find.text('Trade: Electrician'), findsOneWidget);
      expect(find.text('View Agreement'), findsNWidgets(2));
      expect(find.text('Download'), findsNWidgets(2));
      // No storage URL is ever rendered.
      expect(find.textContaining('http'), findsNothing);
    });

    testWidgets('downloads through the acceptance id, not a URL',
        (tester) async {
      final repo = FakeWorkerRepository(
        accepted: [
          AcceptedAgreementEntity(
            id: 'row-1',
            acceptanceId: 'HG-ACC-2026-AAAA',
            documentType: kUstaadGeneralAgreement,
            title: 'HandyGo Ustaad Service Provider Agreement',
            version: '1.0',
            agreementLocale: 'ur_Latn',
            applicableTrade: null,
            acceptedAt: DateTime.utc(2026, 8, 3, 9, 5),
          ),
        ],
      );
      await _pump(tester, repo, home: const WorkerAgreementsPage());

      await tester.tap(find.text('Download'));
      await tester.pumpAndSettle();

      expect(repo.lastDownloadedAcceptanceId, 'HG-ACC-2026-AAAA');
    });

    testWidgets('says so plainly when nothing has been accepted yet',
        (tester) async {
      await _pump(
        tester,
        FakeWorkerRepository(),
        home: const WorkerAgreementsPage(),
      );

      expect(
        find.text('You have not accepted any agreements yet.'),
        findsOneWidget,
      );
    });

    testWidgets('stays left-to-right in Urdu', (tester) async {
      await _pump(
        tester,
        FakeWorkerRepository(),
        home: const WorkerAgreementsPage(),
        locale: AppLocale.urdu,
      );

      final scaffold = tester.element(find.byType(Scaffold).first);
      expect(Directionality.of(scaffold), TextDirection.ltr);
    });
  });
}
