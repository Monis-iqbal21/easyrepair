import '../../../auth/presentation/pages/ustaad_register_step4_page.dart';
import '../../domain/entities/worker_profile_entity.dart';

/// Where an Ustaad with unfinished onboarding should be sent.
///
/// ## Why this is a decision and not a constant
///
/// Registration creates the account at the end of Step 3, in DRAFT. An Ustaad
/// who closes the app between Step 3 and Step 4 therefore comes back to a real
/// account whose profile already holds everything Step 3 collected — name,
/// CNIC number, address, trade — but no CNIC images and no accepted
/// agreements. Sending them through the legacy full form would ask again for
/// all of the former to get at the latter.
///
/// So when the profile already carries the Step 3 data, they resume at Step 4,
/// which reads its own state from the backend (uploaded documents from the
/// profile, agreements from the template endpoint) and needs nothing from the
/// in-memory registration draft that died with the previous session.
///
/// A profile that does NOT carry that data is a legacy DRAFT from before this
/// flow existed, or one abandoned mid-Step-3. There is no safe way to
/// reconstruct which fields are missing from a partial profile, so those fall
/// back to the legacy completion form — which is exactly what it is for, and
/// exactly why it is still routed.
///
/// CHANGES_REQUIRED always goes to the legacy form: an admin has asked for
/// specific corrections that may touch anything, including fields Step 4 does
/// not show.
String resumeOnboardingRoute(WorkerProfileEntity profile) {
  final canResumeVerification =
      profile.onboardingStatus == 'DRAFT' && profile.hasRegistrationProfileData;
  return canResumeVerification
      ? UstaadRegisterStep4Page.route
      : legacyProfileCompletionRoute;
}

/// The pre-existing completion form. Still routed, still needed — for legacy
/// DRAFT profiles, for CHANGES_REQUIRED, and for anything the resume path
/// cannot safely reconstruct.
const legacyProfileCompletionRoute = '/worker/profile-completion';
