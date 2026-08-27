import 'package:flutter_test/flutter_test.dart';
import 'package:handygo_app/features/auth/presentation/pages/ustaad_register_step4_page.dart';
import 'package:handygo_app/features/worker/domain/entities/worker_profile_entity.dart';
import 'package:handygo_app/features/worker/domain/entities/worker_skill_entity.dart';
import 'package:handygo_app/features/worker/domain/entities/worker_stats_entity.dart';
import 'package:handygo_app/features/worker/presentation/widgets/onboarding_routes.dart';

/// What an Ustaad's `onboardingStatus` actually means to the UI.
///
/// The bug this covers: everything used to branch on `!isOnboardingApproved`,
/// which lumped "you never finished your forms" together with "an admin has
/// not looked at your forms yet". A submitted Ustaad was shown a "complete
/// your profile" call to action for a profile they had already completed, and
/// tapping it opened a form the backend refuses edits from.

WorkerProfileEntity _profile({
  required String onboardingStatus,
  String? fullLegalName = 'Kamran Sheikh',
  String? cnicNumber = '42101-1234567-1',
  String? residentialAddress = 'B-42, Street 14, Saddar',
  // Collected by Step 3 and required by `submitProfileForReview`. Step 4 has
  // no input for any of them, so a profile missing one cannot be completed
  // there — see the resume group below.
  String? fatherName = 'Sheikh Rafiq',
  String? dateOfBirth = '1995-04-02',
  bool legalNameConfirmed = true,
  List<WorkerSkillEntity> skills = const [
    WorkerSkillEntity(
      id: 's1',
      categoryId: 'c1',
      categoryName: 'Electrician',
      yearsExperience: 3,
    ),
  ],
}) {
  return WorkerProfileEntity(
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
    cnicNumber: cnicNumber,
    residentialAddress: residentialAddress,
    fatherName: fatherName,
    dateOfBirth: dateOfBirth,
    legalNameConfirmedAt:
        legalNameConfirmed ? DateTime(2026, 8, 1) : null,
  );
}

void main() {
  group('the three states are distinguishable', () {
    test('DRAFT still owes us something', () {
      final p = _profile(onboardingStatus: 'DRAFT');
      expect(p.needsProfileAction, isTrue);
      expect(p.isPendingReview, isFalse);
      expect(p.isOnboardingApproved, isFalse);
    });

    test('CHANGES_REQUIRED still owes us something', () {
      final p = _profile(onboardingStatus: 'CHANGES_REQUIRED');
      expect(p.needsProfileAction, isTrue);
      expect(p.isPendingReview, isFalse);
    });

    test('SUBMITTED_FOR_REVIEW owes us nothing — it is waiting on an admin',
        () {
      final p = _profile(onboardingStatus: 'SUBMITTED_FOR_REVIEW');
      expect(p.isPendingReview, isTrue);
      expect(p.needsProfileAction, isFalse,
          reason: 'a submitted profile has no form left to fill in');
      expect(p.isOnboardingApproved, isFalse,
          reason: 'and is still not allowed to work');
    });

    test('APPROVED is neither', () {
      final p = _profile(onboardingStatus: 'APPROVED');
      expect(p.isOnboardingApproved, isTrue);
      expect(p.needsProfileAction, isFalse);
      expect(p.isPendingReview, isFalse);
    });

    test('REJECTED is actionable, and is never mistaken for DRAFT', () {
      final p = _profile(onboardingStatus: 'REJECTED');
      expect(p.isOnboardingRejected, isTrue);
      expect(p.needsProfileAction, isFalse);
      expect(p.isPendingReview, isFalse);
      expect(p.isOnboardingApproved, isFalse);
    });

    test('every non-approved state is still blocked from work', () {
      for (final status in [
        'DRAFT',
        'CHANGES_REQUIRED',
        'SUBMITTED_FOR_REVIEW',
        'REJECTED',
      ]) {
        expect(_profile(onboardingStatus: status).isOnboardingApproved, isFalse,
            reason: '$status must not be treated as approved');
      }
    });
  });

  group('where an unfinished registration resumes', () {
    test('a DRAFT that already carries the Step 3 data resumes at Step 4', () {
      // The account was created at the end of Step 3, so name, father's name,
      // date of birth, CNIC, address, the legal-name confirmation and the one
      // trade are already stored; only the documents and agreements are
      // missing, and Step 4 reads both from the backend.
      final p = _profile(onboardingStatus: 'DRAFT');
      expect(p.hasRegistrationProfileData, isTrue);
      expect(resumeOnboardingRoute(p), UstaadRegisterStep4Page.route);
    });

    test('a legacy DRAFT with no registration data falls back to the old form',
        () {
      for (final p in [
        _profile(onboardingStatus: 'DRAFT', fullLegalName: null),
        _profile(onboardingStatus: 'DRAFT', cnicNumber: ''),
        _profile(onboardingStatus: 'DRAFT', residentialAddress: null),
        _profile(onboardingStatus: 'DRAFT', skills: const []),
        // Step 4 collects none of these, so resuming there would be a loop:
        // Worker Home -> Step 4 -> MISSING_PROFILE_DATA -> Worker Home.
        _profile(onboardingStatus: 'DRAFT', fatherName: null),
        _profile(onboardingStatus: 'DRAFT', dateOfBirth: ''),
        _profile(onboardingStatus: 'DRAFT', legalNameConfirmed: false),
        _profile(
          onboardingStatus: 'DRAFT',
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
      ]) {
        expect(p.hasRegistrationProfileData, isFalse);
        expect(resumeOnboardingRoute(p), legacyProfileCompletionRoute,
            reason: 'a partial profile cannot be safely resumed at Step 4');
      }
    });

    test('CHANGES_REQUIRED always goes to the legacy form — an admin may have '
        'asked for anything', () {
      final p = _profile(onboardingStatus: 'CHANGES_REQUIRED');
      expect(resumeOnboardingRoute(p), legacyProfileCompletionRoute);
    });

    test('the legacy completion route still exists', () {
      expect(legacyProfileCompletionRoute, '/worker/profile-completion');
    });
  });
}
