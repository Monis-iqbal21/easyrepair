import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:go_router/go_router.dart';
import 'package:handygo_app/core/data/cached_result.dart';
import 'package:handygo_app/core/errors/failures.dart';
import 'package:handygo_app/core/l10n/app_locale.dart';
import 'package:handygo_app/core/router/app_router.dart';
import 'package:handygo_app/features/auth/domain/entities/user_entity.dart';
import 'package:handygo_app/features/auth/presentation/pages/ustaad_register_step1_page.dart';
import 'package:handygo_app/features/auth/presentation/pages/ustaad_register_step3_page.dart';
import 'package:handygo_app/features/auth/presentation/pages/ustaad_register_step4_page.dart';
import 'package:handygo_app/features/auth/presentation/providers/ustaad_registration_draft.dart';
import 'package:handygo_app/features/worker/data/repositories/worker_repository_impl.dart';
import 'package:handygo_app/features/worker/domain/entities/category_entity.dart';
import 'package:handygo_app/features/worker/domain/entities/worker_profile_entity.dart';
import 'package:handygo_app/features/worker/domain/entities/worker_skill_entity.dart';
import 'package:handygo_app/features/worker/domain/entities/worker_stats_entity.dart';
import 'package:handygo_app/features/worker/domain/repositories/worker_repository.dart';
import 'package:handygo_app/features/worker/presentation/widgets/onboarding_routes.dart';

import '../../../support/l10n_test_app.dart';

/// Back navigation once registration has created the account, and resuming an
/// abandoned registration.
///
/// The bug: Step 3 creates the Ustaad account and the session goes live while
/// the Ustaad is still standing on `/auth/worker/register/profile`. Step 4's
/// Back popped onto that `/auth` route, `resolveAuthRedirect` saw a logged-in
/// user on a logged-out route, and ejected them to Worker Home mid-registration
/// with no way back in — so a mistake on Step 3 could not be corrected.

const _worker = UserEntity(
  id: 'u1',
  phone: '03378372427',
  role: 'WORKER',
  firstName: 'Kamran',
  lastName: 'Sheikh',
);

const _client = UserEntity(
  id: 'u2',
  phone: '03001234567',
  role: 'CLIENT',
  firstName: 'Ayesha',
  lastName: 'Malik',
);

WorkerProfileEntity _profile({
  String onboardingStatus = 'DRAFT',
  String? fullLegalName = 'Kamran Sheikh',
  String? fatherName = 'Sheikh Rafiq',
  String? dateOfBirth = '1995-04-02',
  String? cnicNumber = '42101-1234567-1',
  String? residentialAddress = 'B-42, Street 14, Saddar',
  DateTime? legalNameConfirmedAt,
  List<WorkerSkillEntity> skills = const [
    WorkerSkillEntity(
      id: 's1',
      categoryId: 'c1',
      categoryName: 'Electrician',
      yearsExperience: 3,
    ),
  ],
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
      skills: skills,
      stats: const WorkerStatsEntity(completedJobs: 0, activeJobs: 0),
      onboardingStatus: onboardingStatus,
      fullLegalName: fullLegalName,
      fatherName: fatherName,
      dateOfBirth: dateOfBirth,
      cnicNumber: cnicNumber,
      residentialAddress: residentialAddress,
      legalNameConfirmedAt:
          legalNameConfirmedAt ?? DateTime(2026, 1, 1),
    );

class _FakeWorkerRepository implements WorkerRepository {
  @override
  Future<Either<Failure, CachedResult<WorkerProfileEntity>>> getProfile() async =>
      Right(CachedResult(_profile()));

  @override
  Future<Either<Failure, List<CategoryEntity>>> getCategories() async =>
      const Right([CategoryEntity(id: 'c1', name: 'Electrician')]);

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  group('resolveAuthRedirect — the one registration exception', () {
    String? redirect(String location, {UserEntity? user}) =>
        resolveAuthRedirect(
          authState: AsyncData(user),
          matchedLocation: location,
        );

    test('a logged-in WORKER may stay on Step 3', () {
      expect(
        redirect(UstaadRegisterStep3Page.route, user: _worker),
        isNull,
        reason:
            'Step 3 creates the account, so the session goes live while the '
            'Ustaad is still on it — and Step 4 Back returns here',
      );
    });

    test('every OTHER /auth route still ejects a logged-in worker', () {
      expect(
        redirect(UstaadRegisterStep1Page.route, user: _worker),
        '/worker/home',
      );
      expect(
        redirect('/auth/worker/register/verify', user: _worker),
        '/worker/home',
      );
      expect(redirect('/auth/role-select', user: _worker), '/worker/home');
      expect(redirect('/welcome', user: _worker), '/worker/home');
    });

    test('a CLIENT is never given the exception', () {
      expect(
        redirect(UstaadRegisterStep3Page.route, user: _client),
        '/client/home',
        reason: 'the exception is scoped to one path AND one role',
      );
    });

    test('a logged-OUT user may still walk into Step 3 normally', () {
      expect(redirect(UstaadRegisterStep3Page.route), isNull);
    });

    test('splash still dispatches', () {
      expect(redirect('/splash', user: _worker), '/worker/home');
      expect(redirect('/splash'), '/welcome');
    });
  });

  group('Step 4 → Back → Step 3 stays inside registration', () {
    testWidgets('the Ustaad lands back on Step 3, not on Worker Home, and the '
        'fields are still editable', (tester) async {
      tester.view.physicalSize = const Size(390, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      // A live worker session — exactly the state Step 3 leaves behind.
      final router = GoRouter(
        initialLocation: UstaadRegisterStep3Page.route,
        redirect: (_, state) => resolveAuthRedirect(
          authState: const AsyncData(_worker),
          matchedLocation: state.matchedLocation,
        ),
        routes: [
          GoRoute(
            path: UstaadRegisterStep3Page.route,
            builder: (_, _) => const UstaadRegisterStep3Page(),
          ),
          GoRoute(
            path: UstaadRegisterStep4Page.route,
            builder: (context, _) => Scaffold(
              body: Center(
                child: Builder(
                  builder: (inner) => TextButton(
                    // Exactly what Step 4's header arrow does.
                    onPressed: () => Navigator.of(inner).maybePop(),
                    child: const Text('STEP_4_BACK'),
                  ),
                ),
              ),
            ),
          ),
          GoRoute(
            path: '/worker/home',
            builder: (_, _) => const Scaffold(body: Text('WORKER_HOME')),
          ),
        ],
      );

      final container = ProviderContainer(
        overrides: [
          workerRepositoryProvider.overrideWithValue(_FakeWorkerRepository()),
        ],
      );
      addTearDown(container.dispose);
      container.read(ustaadRegistrationDraftProvider.notifier).update(
            (d) => d.copyWith(
              fullName: 'Kamran Sheikh',
              cnicNumber: '42101-1234567-1',
              area: 'Saddar',
              street: '14',
              house: 'B-42',
              fatherName: 'Sheikh Rafiq',
              accountCreated: true,
            ),
          );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: localizedRouterApp(router, locale: AppLocale.romanUrdu),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(UstaadRegisterStep3Page), findsOneWidget);

      // Push Step 4 the way Step 3's CTA does, then come back the way Step 4's
      // header does.
      final ctx = tester.element(find.byType(UstaadRegisterStep3Page));
      ctx.push(UstaadRegisterStep4Page.route);
      await tester.pumpAndSettle();
      expect(find.text('STEP_4_BACK'), findsOneWidget);

      await tester.tap(find.text('STEP_4_BACK'));
      await tester.pumpAndSettle();

      expect(
        find.text('WORKER_HOME'),
        findsNothing,
        reason: 'this is the ejection the fix is about',
      );
      expect(find.byType(UstaadRegisterStep3Page), findsOneWidget);

      // Still a working form, with what was entered still in it.
      final area = find.byType(EditableText).at(2);
      expect(
        tester.widget<EditableText>(area).controller.text,
        'Saddar',
      );
      await tester.ensureVisible(area);
      await tester.pump();
      await tester.enterText(area, 'Gulshan');
      await tester.pump();
      expect(tester.widget<EditableText>(area).controller.text, 'Gulshan');
    });
  });

  group('resuming an abandoned registration never loops', () {
    test('a profile carrying everything Step 4 CANNOT fix resumes at Step 4',
        () {
      expect(
        resumeOnboardingRoute(_profile()),
        UstaadRegisterStep4Page.route,
      );
    });

    test('a profile missing father name goes to the legacy form, not Step 4',
        () {
      expect(
        resumeOnboardingRoute(_profile(fatherName: null)),
        legacyProfileCompletionRoute,
        reason: 'Step 4 has no input for it, so resuming there would be '
            'Worker Home → Step 4 → MISSING_PROFILE_DATA → Worker Home',
      );
    });

    test('same for date of birth and the legal-name confirmation', () {
      expect(
        resumeOnboardingRoute(_profile(dateOfBirth: null)),
        legacyProfileCompletionRoute,
      );
      expect(
        resumeOnboardingRoute(
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
            onboardingStatus: 'DRAFT',
            fullLegalName: 'Kamran Sheikh',
            fatherName: 'Sheikh Rafiq',
            dateOfBirth: '1995-04-02',
            cnicNumber: '42101-1234567-1',
            residentialAddress: 'B-42',
            // Never confirmed.
          ),
        ),
        legacyProfileCompletionRoute,
      );
    });

    test('a legacy profile with two skills goes to the legacy form', () {
      expect(
        resumeOnboardingRoute(
          _profile(
            skills: const [
              WorkerSkillEntity(
                id: 's1',
                categoryId: 'c1',
                categoryName: 'Electrician',
                yearsExperience: 3,
              ),
              WorkerSkillEntity(
                id: 's2',
                categoryId: 'c2',
                categoryName: 'Plumber',
                yearsExperience: 1,
              ),
            ],
          ),
        ),
        legacyProfileCompletionRoute,
        reason: 'exactly one skill is what the submit endpoint requires and '
            'what profileCompleted means',
      );
    });

    test('CHANGES_REQUIRED always goes to the legacy form', () {
      expect(
        resumeOnboardingRoute(_profile(onboardingStatus: 'CHANGES_REQUIRED')),
        legacyProfileCompletionRoute,
      );
    });
  });
}
