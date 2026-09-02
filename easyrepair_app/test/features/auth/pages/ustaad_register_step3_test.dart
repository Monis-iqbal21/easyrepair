import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:go_router/go_router.dart';
import 'package:handygo_app/core/data/cached_result.dart';
import 'package:handygo_app/core/errors/failures.dart';
import 'package:handygo_app/core/l10n/app_locale.dart';
import 'package:handygo_app/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:handygo_app/features/auth/domain/entities/auth_tokens_entity.dart';
import 'package:handygo_app/features/auth/domain/entities/user_entity.dart';
import 'package:handygo_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:handygo_app/features/auth/presentation/pages/ustaad_register_step3_page.dart';
import 'package:handygo_app/features/auth/presentation/providers/ustaad_registration_draft.dart';
import 'package:handygo_app/features/worker/domain/entities/category_entity.dart';
import 'package:handygo_app/features/worker/domain/entities/worker_profile_entity.dart';
import 'package:handygo_app/features/worker/domain/entities/worker_skill_entity.dart';
import 'package:handygo_app/features/worker/domain/entities/worker_stats_entity.dart';
import 'package:handygo_app/features/worker/data/repositories/worker_repository_impl.dart';
import 'package:handygo_app/features/worker/domain/repositories/worker_repository.dart';

import '../../../support/l10n_test_app.dart';

/// Step 3 of Ustaad registration — what it collects and what it refuses to
/// walk past.
///
/// Two structural bugs are covered here:
///
///  * The step never collected `fatherName`, `dateOfBirth` or the legal-name
///    confirmation, all three of which `submitProfileForReview` requires. Step
///    4's Submit was therefore rejected with MISSING_PROFILE_DATA every single
///    time — registration could not be completed at all.
///  * Trades were multi-select against a backend that hard-rejects more than
///    one (`Only one main skill is allowed.`, `@ArrayMaxSize(1)`), and the
///    resulting failure was discarded: the flow moved on to Step 4 regardless.
///
/// Everything asserted below is about what actually reached the repository.

// ── Fakes ───────────────────────────────────────────────────────────────────

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({this.registerSucceeds = true});

  final bool registerSucceeds;
  int registerCalls = 0;
  String? lastCategoryId;

  @override
  Future<Either<Failure, AuthTokensEntity>> workerOtpRegister({
    required String fullName,
    required String phone,
    String? otp,
    required String password,
    required String categoryId,
    String? registrationToken,
  }) async {
    registerCalls++;
    lastCategoryId = categoryId;
    if (!registerSucceeds) return const Left(ServerFailure('nope'));
    return const Right(
      AuthTokensEntity(
        accessToken: 'a',
        refreshToken: 'r',
        user: UserEntity(
          id: 'u1',
          phone: '03378372427',
          role: 'WORKER',
          firstName: 'Kamran',
          lastName: 'Sheikh',
        ),
      ),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _FakeWorkerRepository implements WorkerRepository {
  _FakeWorkerRepository({
    this.avatarSucceeds = true,
    this.saveSucceeds = true,
    this.skillsSucceed = true,
    this.categoryResult = const Right([
      CategoryEntity(id: 'c1', name: 'Electrician'),
      CategoryEntity(id: 'c2', name: 'Plumber'),
    ]),
  });

  final bool avatarSucceeds;
  final bool saveSucceeds;
  final bool skillsSucceed;
  final Either<Failure, List<CategoryEntity>> categoryResult;

  int avatarUploads = 0;
  int saveCalls = 0;
  List<List<String>> skillCalls = [];
  Map<String, Object?>? lastSaved;

  WorkerProfileEntity profile = const WorkerProfileEntity(
    id: 'w1',
    userId: 'u1',
    firstName: 'Kamran',
    lastName: 'Sheikh',
    status: 'ACTIVE',
    verificationStatus: 'PENDING',
    availabilityStatus: AvailabilityStatus.offline,
    rating: 0,
    totalRatings: 0,
    skills: [
      WorkerSkillEntity(
        id: 's1',
        categoryId: 'c1',
        categoryName: 'Electrician',
        yearsExperience: 3,
      ),
    ],
    stats: WorkerStatsEntity(completedJobs: 0, activeJobs: 0),
    onboardingStatus: 'DRAFT',
  );

  @override
  Future<Either<Failure, List<CategoryEntity>>> getCategories() async =>
      categoryResult;

  @override
  Future<Either<Failure, CachedResult<WorkerProfileEntity>>>
  getProfile() async => Right(CachedResult(profile));

  @override
  Future<Either<Failure, String>> uploadAvatar(File file) async {
    avatarUploads++;
    return avatarSucceeds
        ? const Right('https://cdn/a.jpg')
        : const Left(ServerFailure('avatar exploded'));
  }

  @override
  Future<Either<Failure, List<WorkerSkillEntity>>> updateSkills(
    List<String> categoryIds, {
    int? yearsExperience,
  }) async {
    skillCalls.add(categoryIds);
    if (!skillsSucceed) return const Left(ServerFailure('skills exploded'));
    return Right([
      for (final id in categoryIds)
        WorkerSkillEntity(
          id: 's-$id',
          categoryId: id,
          categoryName: id,
          yearsExperience: 3,
        ),
    ]);
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
    saveCalls++;
    lastSaved = {
      'fullLegalName': fullLegalName,
      'residentialAddress': residentialAddress,
      'cnicNumber': cnicNumber,
      'fatherName': fatherName,
      'dateOfBirth': dateOfBirth,
      'experienceYears': experienceYears,
      'legalNameConfirmed': legalNameConfirmed,
    };
    return saveSucceeds
        ? const Right(null)
        : const Left(ServerFailure('save exploded'));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

// ── Harness ─────────────────────────────────────────────────────────────────

/// Everything Steps 1 and 2 would have put in the draft by the time Step 3 is
/// reached, so this file can start where the bugs are.
UstaadRegistrationDraft _seed({bool accountCreated = false}) =>
    UstaadRegistrationDraft(
      fullName: 'Kamran Sheikh',
      phone: '03378372427',
      cnicNumber: '42101-1234567-1',
      password: 'password123',
      registrationToken: 'reg-token',
      accountCreated: accountCreated,
    );

late ProviderContainer _container;

/// Builds the app around a container that is seeded BEFORE the first frame —
/// Steps 1 and 2 would have filled the draft in by the time this screen is
/// reached, and a provider cannot be written to during build.
Widget _app({
  required _FakeAuthRepository auth,
  required _FakeWorkerRepository worker,
  UstaadRegistrationDraft? draft,
}) {
  final router = GoRouter(
    initialLocation: UstaadRegisterStep3Page.route,
    routes: [
      GoRoute(
        path: UstaadRegisterStep3Page.route,
        builder: (_, _) => const UstaadRegisterStep3Page(),
      ),
      GoRoute(
        path: '/worker/register/verification',
        builder: (_, _) => const Scaffold(body: Text('STEP_4')),
      ),
      GoRoute(
        path: '/worker/home',
        builder: (_, _) => const Scaffold(body: Text('WORKER_HOME')),
      ),
    ],
  );

  _container = ProviderContainer(
    overrides: [
      authRepositoryProvider.overrideWithValue(auth),
      workerRepositoryProvider.overrideWithValue(worker),
    ],
  );
  addTearDown(_container.dispose);
  if (draft != null) {
    _container
        .read(ustaadRegistrationDraftProvider.notifier)
        .update((_) => draft);
  }

  return UncontrolledProviderScope(
    container: _container,
    child: localizedRouterApp(router, locale: AppLocale.romanUrdu),
  );
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

// Field order on the page.
const _fatherName = 0;
const _area = 2;
const _street = 3;
const _house = 4;

Future<void> _type(WidgetTester tester, int index, String text) async {
  await tester.ensureVisible(find.byType(EditableText).at(index));
  await _settle(tester);
  await tester.enterText(find.byType(EditableText).at(index), text);
  await _settle(tester);
}

Future<void> _tapText(WidgetTester tester, String text) async {
  await tester.ensureVisible(find.text(text).first);
  await _settle(tester);
  await tester.tap(find.text(text).first);
  await _settle(tester);
}

/// Fills everything Step 3 requires, so a test only has to remove the one
/// thing it is about.
Future<void> _fillEverything(
  WidgetTester tester, {
  bool photo = true,
  bool fatherName = true,
  bool dateOfBirth = true,
  bool trade = true,
  bool experience = true,
  bool address = true,
  bool legalName = true,
}) async {
  if (fatherName) await _type(tester, _fatherName, 'Sheikh Rafiq');
  if (dateOfBirth) await _pickDob(tester);
  if (legalName) await _tapCheckbox(tester);
  if (trade) await _tapText(tester, 'Electrician');
  if (experience) await _tapText(tester, '3-5');
  if (address) {
    await _type(tester, _area, 'Saddar');
    await _type(tester, _street, '14');
    await _type(tester, _house, 'B-42');
  }
  if (photo) await _pickPhoto(tester);
}

/// The photo and date pickers both leave the app, which a widget test cannot
/// do — these drive the state the picker would have produced instead, through
/// the page's own public surface where one exists.
Future<void> _pickDob(WidgetTester tester) async {
  await tester.ensureVisible(find.byType(EditableText).at(1));
  await _settle(tester);
  await tester.tap(find.byType(EditableText).at(1));
  await tester.pumpAndSettle();
  // The Material date picker opens on the initial date (25 years ago); OK
  // accepts it unchanged, which is all this needs.
  await tester.tap(find.text('OK'));
  await tester.pumpAndSettle();
}

Future<void> _tapCheckbox(WidgetTester tester) async {
  await tester.ensureVisible(find.byType(Checkbox));
  await _settle(tester);
  await tester.tap(find.byType(Checkbox));
  await _settle(tester);
}

/// image_picker cannot run in a widget test, so the photo is seeded straight
/// into the draft — the page reads it back on the next rebuild the same way it
/// would after a real pick.
Future<void> _pickPhoto(WidgetTester tester) async {
  _container
      .read(ustaadRegistrationDraftProvider.notifier)
      .update((d) => d.copyWith(photo: File('avatar.jpg')));
  await _settle(tester);
}

void main() {
  group('Worker registration service availability', () {
    testWidgets('renders ACTIVE only and hides INACTIVE/SOON', (tester) async {
      final worker = _FakeWorkerRepository(
        categoryResult: const Right([
          CategoryEntity(id: 'active', name: 'Electrician'),
          CategoryEntity(
            id: 'inactive',
            name: 'Disabled Trade',
            availabilityStatus: ServiceAvailabilityStatus.inactive,
          ),
          CategoryEntity(
            id: 'soon',
            name: 'Future Trade',
            availabilityStatus: ServiceAvailabilityStatus.soon,
          ),
        ]),
      );
      await tester.pumpWidget(
        _app(auth: _FakeAuthRepository(), worker: worker, draft: _seed()),
      );
      await _settle(tester);

      expect(find.text('Electrician'), findsOneWidget);
      expect(find.text('Disabled Trade'), findsNothing);
      expect(find.text('Future Trade'), findsNothing);
    });

    testWidgets('preserves the category error state', (tester) async {
      final worker = _FakeWorkerRepository(
        categoryResult: const Left(ServerFailure('offline')),
      );
      await tester.pumpWidget(
        _app(auth: _FakeAuthRepository(), worker: worker, draft: _seed()),
      );
      await _settle(tester);

      expect(
        find.text('Skills load nahi ho sakin. Dobara koshish karein.'),
        findsOneWidget,
      );
    });

    testWidgets('preserves an empty service list without stale choices', (
      tester,
    ) async {
      final worker = _FakeWorkerRepository(categoryResult: const Right([]));
      await tester.pumpWidget(
        _app(auth: _FakeAuthRepository(), worker: worker, draft: _seed()),
      );
      await _settle(tester);

      expect(find.text('Electrician'), findsNothing);
      expect(find.text('Plumber'), findsNothing);
    });
  });

  // The seeded photo has to survive the page's own initState hydration, so
  // tests that need it re-enter the page with it already in the draft.
  group('required fields', () {
    testWidgets('an empty form explains itself instead of doing nothing', (
      tester,
    ) async {
      final auth = _FakeAuthRepository();
      final worker = _FakeWorkerRepository();
      await tester.pumpWidget(_app(auth: auth, worker: worker, draft: _seed()));
      await _settle(tester);

      await _tapText(tester, 'Aage');

      expect(
        auth.registerCalls,
        0,
        reason: 'nothing may be created from an incomplete form',
      );
      expect(
        find.byType(SnackBar),
        findsOneWidget,
        reason: 'a disabled, silent button is what left Ustaads stuck here',
      );
      // Every missing field says so, not just the first one.
      expect(find.text('Walid ka naam lazmi hai.'), findsOneWidget);
      expect(find.text('Tareekh-e-paidaish lazmi hai.'), findsOneWidget);
      expect(find.text('Ye tasdeeq zaroori hai.'), findsOneWidget);
      expect(
        find.text('Baraye meherbani apna buniyadi hunar muntakhab karein.'),
        findsOneWidget,
      );
      // The photo and each address line get the shared "Zaroori hai".
      expect(find.text('Zaroori hai'), findsWidgets);
      expect(
        find.text('Baraye meherbani neeche nishan zad khane mukammal karein.'),
        findsOneWidget,
        reason: 'and the snackbar points at them',
      );
    });

    testWidgets('the landmark is genuinely optional', (tester) async {
      final auth = _FakeAuthRepository();
      final worker = _FakeWorkerRepository();
      await tester.pumpWidget(
        _app(
          auth: auth,
          worker: worker,
          draft: _seed().copyWith(photo: File('avatar.jpg')),
        ),
      );
      await _settle(tester);

      await _fillEverything(tester, photo: false);
      await _tapText(tester, 'Aage');
      await _settle(tester);

      expect(auth.registerCalls, 1);
      expect(find.text('STEP_4'), findsOneWidget);
    });
  });

  group('the trade is single-select', () {
    testWidgets('picking a second trade REPLACES the first', (tester) async {
      final auth = _FakeAuthRepository();
      final worker = _FakeWorkerRepository();
      await tester.pumpWidget(
        _app(
          auth: auth,
          worker: worker,
          draft: _seed().copyWith(photo: File('avatar.jpg')),
        ),
      );
      await _settle(tester);

      await _tapText(tester, 'Electrician');
      expect(_container.read(ustaadRegistrationDraftProvider).categoryId, 'c1');

      await _tapText(tester, 'Plumber');
      expect(
        _container.read(ustaadRegistrationDraftProvider).categoryId,
        'c2',
        reason: 'the second tap replaces rather than adds',
      );
    });

    testWidgets('registration is created with exactly one category, and '
        'updateSkills is never sent more than one', (tester) async {
      final auth = _FakeAuthRepository();
      final worker = _FakeWorkerRepository();
      await tester.pumpWidget(
        _app(
          auth: auth,
          worker: worker,
          draft: _seed().copyWith(photo: File('avatar.jpg')),
        ),
      );
      await _settle(tester);

      await _fillEverything(tester, photo: false, trade: false);
      await _tapText(tester, 'Electrician');
      await _tapText(tester, 'Plumber');
      await _tapText(tester, 'Aage');
      await _settle(tester);

      expect(auth.lastCategoryId, 'c2');
      for (final call in worker.skillCalls) {
        expect(
          call.length,
          1,
          reason: 'updateSkills rejects anything longer outright',
        );
      }
    });

    testWidgets('a return trip re-asserts the trade as exactly one skill', (
      tester,
    ) async {
      final auth = _FakeAuthRepository();
      final worker = _FakeWorkerRepository();
      await tester.pumpWidget(
        _app(
          auth: auth,
          worker: worker,
          // The account already exists — this is Step 4's Back, then Aage.
          draft: _seed(accountCreated: true).copyWith(photo: File('a.jpg')),
        ),
      );
      await _settle(tester);

      await _fillEverything(tester, photo: false);
      await _tapText(tester, 'Aage');
      await _settle(tester);

      expect(
        auth.registerCalls,
        0,
        reason: 'the account must never be created twice',
      );
      expect(worker.skillCalls, [
        ['c1'],
      ]);
      expect(find.text('STEP_4'), findsOneWidget);
    });
  });

  group('what actually reaches the backend', () {
    testWidgets('father name, date of birth and the legal-name confirmation '
        'are all sent — the three the submit endpoint refuses without', (
      tester,
    ) async {
      final auth = _FakeAuthRepository();
      final worker = _FakeWorkerRepository();
      await tester.pumpWidget(
        _app(
          auth: auth,
          worker: worker,
          draft: _seed().copyWith(photo: File('avatar.jpg')),
        ),
      );
      await _settle(tester);

      await _fillEverything(tester, photo: false);
      await _tapText(tester, 'Aage');
      await _settle(tester);

      final saved = worker.lastSaved!;
      expect(saved['fatherName'], 'Sheikh Rafiq');
      expect(
        saved['dateOfBirth'],
        matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')),
        reason: 'the ISO shape the backend stores and the document prints',
      );
      expect(saved['legalNameConfirmed'], isTrue);
      expect(saved['fullLegalName'], 'Kamran Sheikh');
      expect(saved['cnicNumber'], '42101-1234567-1');
      expect(saved['experienceYears'], 3);
      expect(saved['residentialAddress'], contains('B-42'));
      expect(saved['residentialAddress'], contains('Saddar'));
    });
  });

  group('a failed step blocks the next one', () {
    Future<_FakeWorkerRepository> run(
      WidgetTester tester, {
      required _FakeAuthRepository auth,
      required _FakeWorkerRepository worker,
    }) async {
      await tester.pumpWidget(
        _app(
          auth: auth,
          worker: worker,
          draft: _seed().copyWith(photo: File('avatar.jpg')),
        ),
      );
      await _settle(tester);
      await _fillEverything(tester, photo: false);
      await _tapText(tester, 'Aage');
      await _settle(tester);
      return worker;
    }

    testWidgets('account creation failure stays on Step 3', (tester) async {
      final worker = _FakeWorkerRepository();
      await run(
        tester,
        auth: _FakeAuthRepository(registerSucceeds: false),
        worker: worker,
      );

      expect(find.text('STEP_4'), findsNothing);
      expect(find.byType(UstaadRegisterStep3Page), findsOneWidget);
      expect(
        worker.saveCalls,
        0,
        reason: 'nothing may be saved against an account that was not created',
      );
    });

    testWidgets('avatar upload failure stays on Step 3', (tester) async {
      final worker = await run(
        tester,
        auth: _FakeAuthRepository(),
        worker: _FakeWorkerRepository(avatarSucceeds: false),
      );

      expect(worker.avatarUploads, 1);
      expect(
        find.text('STEP_4'),
        findsNothing,
        reason:
            'the upload result used to be discarded and the flow carried '
            'on with no profile photo',
      );
      expect(
        worker.saveCalls,
        0,
        reason: 'and it must not save over a failed upload either',
      );
    });

    testWidgets('profile save failure stays on Step 3', (tester) async {
      final worker = await run(
        tester,
        auth: _FakeAuthRepository(),
        worker: _FakeWorkerRepository(saveSucceeds: false),
      );

      expect(worker.saveCalls, 1);
      expect(find.text('STEP_4'), findsNothing);
      expect(find.byType(UstaadRegisterStep3Page), findsOneWidget);
    });

    testWidgets('skill persistence failure on a return trip stays on Step 3', (
      tester,
    ) async {
      final worker = _FakeWorkerRepository(skillsSucceed: false);
      await tester.pumpWidget(
        _app(
          auth: _FakeAuthRepository(),
          worker: worker,
          draft: _seed(accountCreated: true).copyWith(photo: File('a.jpg')),
        ),
      );
      await _settle(tester);
      await _fillEverything(tester, photo: false);
      await _tapText(tester, 'Aage');
      await _settle(tester);

      expect(worker.skillCalls.length, 1);
      expect(worker.saveCalls, 0);
      expect(find.text('STEP_4'), findsNothing);
    });
  });
}
