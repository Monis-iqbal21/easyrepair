import 'package:flutter/material.dart';
import '../widgets/onboarding_routes.dart';
import '../../../../core/theme/app_semantic_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

import 'package:intl/intl.dart';

import '../../../../core/errors/failure_messages.dart';
import '../../../../core/location/location_availability.dart';
import '../../../../core/location/location_recovery_snack.dart';
import '../../../../core/network/offline_banner.dart';
import '../../../../core/utils/currency_utils.dart';
import '../../../notifications/presentation/providers/notification_providers.dart';
import '../../data/repositories/worker_repository_impl.dart';
import '../../domain/entities/worker_profile_entity.dart';
import '../../domain/entities/ongoing_job_entity.dart';
import '../../domain/entities/category_entity.dart';
import '../../domain/entities/worker_review_entity.dart';
import '../providers/worker_providers.dart';
import '../providers/worker_review_providers.dart';
import '../utils/worker_status_labels.dart';
import '../widgets/worker_bottom_nav_bar.dart';
import '../widgets/profile_completion_modal.dart';
import '../../../../core/l10n/l10n_extensions.dart';
import '../../../../l10n/app_localizations.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
//
// Every colour on this screen comes from `context.semanticColors` — see
// `core/theme/app_semantic_colors.dart`, the one place HandyGo's colours are
// decided. `_kLight`, `_kBorder`, `_kBg` and `_kHero` are gone; so is every
// use of `_kOrange` (`#DB6234`, the old EasyRepair orange, which the Ustaad
// prototype does not contain at all).
//
// The three below survive for exactly ONE widget: `_LocationLabel`, which
// Anzal asked to leave untouched in this pass. Nothing else may read them —
// if a new widget needs a colour, it takes a token.
const _kOrange     = Color(0xFFDB6234);
const _kDark       = Color(0xFF1A1A1A);
const _kGray       = Color(0xFF6B7280);

// ── Prototype geometry ────────────────────────────────────────────────────────
//
// Taken from the Ustaad prototype's stylesheet
// (`06 Handover to Monis/05 Design & UI/prototype/source/Handygo Ustaad V1.0 -
// Prototype.dc.html`, CSS lines 15–119).
//
// The prototype uses NO shadow anywhere inside a screen: `.crd` (CSS line 54)
// is `background + border-radius 16 + 1px solid var(--line)` and nothing else.
// Its only two `box-shadow` rules are on the phone frame and the toast, which
// are not app surfaces. Every box-shadow this screen used to carry has been
// replaced by a hairline `c.border`.
const double _rCard = 16;      // .crd / .tile
const double _rButton = 14;    // .btnp
const double _rPill = 999;     // .tg / .icb / .av
const double _hButton = 52;    // .btnp min-height
const double _gap = 14;        // .bd { gap: 14px }

/// A section label in the prototype's `.sec` treatment (CSS line 81):
/// 12.5px / 700 / uppercase / letter-spacing .06em / `--ink2`.
///
/// The uppercasing is Latin-only. Urdu script has no letter case, so
/// `toUpperCase()` is a no-op in `ur` and merely looks like shouting in
/// `ur_Latn`; both keep the size, spacing and colour but not the transform.
class _SectionHeading extends StatelessWidget {
  final String text;
  const _SectionHeading(this.text);

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;
    final isLatinCased = Localizations.localeOf(context).languageCode == 'en';
    return Text(
      isLatinCased ? text.toUpperCase() : text,
      style: TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.75, // .06em at 12.5px
        color: c.textSecondary,
      ),
    );
  }
}

class WorkerHomePage extends ConsumerStatefulWidget {
  const WorkerHomePage({super.key});

  @override
  ConsumerState<WorkerHomePage> createState() => _WorkerHomePageState();
}

class _WorkerHomePageState extends ConsumerState<WorkerHomePage>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(locationTrackerProvider.notifier).onAppResumed();
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(workerProfileProvider);
    final isShowingCachedData =
        ref.watch(workerProfileIsOfflineProvider) && profileAsync.hasValue;

    // Show the "complete your profile" modal once per app session — fires on
    // the first Home build after login/registration/resume-triggered refresh
    // while onboarding isn't APPROVED yet. The persistent banner in
    // _HomeBody covers returning to this screen afterward.
    ref.listen(workerProfileProvider, (previous, next) {
      final profile = next.valueOrNull;
      if (profile == null || profile.isOnboardingApproved) return;
      // Only an Ustaad who still owes us something gets the modal. A profile
      // that is already SUBMITTED_FOR_REVIEW has nothing left to fill in —
      // asking again would be asking for what they just gave, and the backend
      // would refuse the edits anyway.
      if (!profile.needsProfileAction) return;
      if (ref.read(onboardingModalShownProvider)) return;
      ref.read(onboardingModalShownProvider.notifier).state = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          showProfileCompletionModal(
            context,
            route: resumeOnboardingRoute(profile),
          );
        }
      });
    });

    final c = context.semanticColors;

    return Scaffold(
      backgroundColor: c.background,
      extendBody: true,
      body: SafeArea(
        bottom: false,
        child: profileAsync.when(
          skipError: true,
          loading: () => Center(
            child: CircularProgressIndicator(color: c.primary),
          ),
          error: (err, _) => _ErrorView(
            message: failureMessage(context.l10n, err),
            onRetry: () => ref.read(workerProfileProvider.notifier).refresh(),
          ),
          data: (profile) => Column(
            children: [
              if (isShowingCachedData) const OfflineDataBanner(),
              Expanded(child: _HomeBody(profile: profile)),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const WorkerBottomNavBar(currentIndex: 0),
    );
  }
}

// ── Main body ─────────────────────────────────────────────────────────────────

class _HomeBody extends ConsumerWidget {
  final WorkerProfileEntity profile;
  const _HomeBody({required this.profile});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      color: context.semanticColors.primary,
      onRefresh: () => ref.read(workerProfileProvider.notifier).refresh(),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          // Header
          const SliverToBoxAdapter(child: _Header()),
          // Persistent profile-completion CTA — always visible (not just the
          // modal) so the worker has a way back without waiting for a resume.
          // Three different reasons an Ustaad may not be working yet, and
          // three different things to say about them — see the widgets below.
          if (profile.needsProfileAction)
            SliverToBoxAdapter(
              child: _ProfileActionBanner(profile: profile),
            )
          else if (profile.isPendingReview)
            const SliverToBoxAdapter(child: _PendingReviewCard())
          else if (profile.isOnboardingRejected)
            SliverToBoxAdapter(
              child: _ProfileActionBanner(profile: profile),
            ),
          // Hero card (online status + stats)
          SliverToBoxAdapter(child: _HeroCard(profile: profile)),
          // View New Jobs CTA
          SliverToBoxAdapter(child: _NewJobsCta()),
          // Today section
          SliverToBoxAdapter(child: _TodaySection(profile: profile)),
          // Performance section
          SliverToBoxAdapter(child: _PerformanceSection(profile: profile)),
          // Reviews section
          SliverToBoxAdapter(child: _ReviewsSection(profile: profile)),
          // Bottom spacer for nav bar
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }
}

// ── Onboarding status cards ──────────────────────────────────────────────────
//
// `!isOnboardingApproved` used to drive a single banner that always linked to
// the profile-completion form. That was wrong for a submitted Ustaad: they
// were shown a "complete your profile" call to action for a profile they had
// already completed, and tapping it opened a form the backend refuses to
// accept edits from. The two states are now separate widgets.

/// DRAFT and CHANGES_REQUIRED — the Ustaad still has something to do, so this
/// is a call to action and it navigates.
///
/// REJECTED reuses it deliberately: a rejected profile is actionable too, and
/// its existing wording already says so.
class _ProfileActionBanner extends StatelessWidget {
  final WorkerProfileEntity profile;
  const _ProfileActionBanner({required this.profile});

  /// [profile.onboardingStatus] is the raw backend token — only the wording
  /// is translated.
  (String, String) _statusLabel(AppLocalizations l10n) =>
      switch (profile.onboardingStatus) {
        'CHANGES_REQUIRED' => (
            l10n.workerOnboardingChangesRequired,
            l10n.workerOnboardingChangesRequiredBody,
          ),
        'REJECTED' => (
            l10n.bidStatusRejected,
            l10n.workerOnboardingRejectedBody,
          ),
        _ => (
            l10n.workerProfileIncomplete,
            l10n.workerApprovalRequired,
          ),
      };

  @override
  Widget build(BuildContext context) {
    final (title, subtitle) = _statusLabel(context.l10n);
    final colors = context.semanticColors;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, _gap, 20, 0),
      child: GestureDetector(
        onTap: () => context.push(resumeOnboardingRoute(profile)),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: colors.urgentSoft,
            borderRadius: BorderRadius.circular(_rCard),
            border: Border.all(color: colors.urgent),
          ),
          child: Row(
            children: [
              Icon(Icons.assignment_late_outlined,
                  color: colors.urgent, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: colors.urgent,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 14,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: colors.urgent, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

/// SUBMITTED_FOR_REVIEW — informational only.
///
/// No chevron, no tap target and no route: there is nothing for the Ustaad to
/// open. The restrictions on work are unchanged; this just explains that the
/// reason is an admin queue rather than a missing form.
class _PendingReviewCard extends StatelessWidget {
  const _PendingReviewCard();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.semanticColors;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, _gap, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colors.softTeal,
          borderRadius: BorderRadius.circular(_rCard),
          border: Border.all(color: colors.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.hourglass_top_rounded, color: colors.primary, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.workerPendingReviewTitle,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.workerPendingReviewBody,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.45,
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────
//
// Left: the worker's main skill (e.g. "Electrician") — logout moved to
// Profile/settings, it no longer lives on Home top-left.
// Right: current area/road label, then the notification bell.

class _Header extends ConsumerWidget {
  const _Header();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final skills = ref.watch(workerProfileProvider).valueOrNull?.skills;
    final skillName = (skills != null && skills.isNotEmpty) ? skills.first.categoryName : null;
    final c = context.semanticColors;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Row(
        children: [
          Expanded(
            child: Text(
              skillName ?? context.l10n.workerSkillNotSelected,
              // Prototype `.h1` (CSS line 42): 18px / 700 / -.01em. The
              // prototype tops out at weight 700 — there is no w800 in it.
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: skillName != null ? c.textPrimary : c.textSecondary,
                letterSpacing: -0.18,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const _LocationLabel(),
          const SizedBox(width: 10),
          // Notification bell
          GestureDetector(
            onTap: () => context.push('/notifications'),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: c.surface,
                    shape: BoxShape.circle,
                    border: Border.all(color: c.border),
                  ),
                  child: Icon(
                    Icons.notifications_outlined,
                    size: 20,
                    color: c.textPrimary,
                  ),
                ),
                Consumer(builder: (context, ref, child) {
                  final count =
                      ref.watch(unreadNotificationCountProvider).valueOrNull ?? 0;
                  if (count == 0) return const SizedBox.shrink();
                  return Positioned(
                    top: 2,
                    right: 2,
                    child: Container(
                      width: 17,
                      height: 17,
                      decoration: BoxDecoration(
                        color: c.urgent,
                        shape: BoxShape.circle,
                        border: Border.all(color: c.surface, width: 1.5),
                      ),
                      child: Center(
                        child: Text(
                          count > 9 ? '9+' : '$count',
                          style: TextStyle(
                            fontSize: 10,
                            height: 1,
                            color: c.onPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Current area/road label — tap to manually refresh live location ───────────
//
// Shows a short area/road name (never a full address). Tapping re-fetches the
// device's current position (bounded permission + GPS timeouts), reverse-
// geocodes it, and — only if it moved meaningfully from the background
// tracker's last synced fix — pushes it to the backend via the same
// /workers/location endpoint the tracker itself uses, so client-side worker
// discovery reflects it immediately without waiting for the next tracker
// tick. Entirely self-contained: never touches LocationTrackerNotifier's own
// state/timer, so it can't interfere with the existing background tracker.
class _LocationLabel extends ConsumerStatefulWidget {
  const _LocationLabel();

  @override
  ConsumerState<_LocationLabel> createState() => _LocationLabelState();
}

class _LocationLabelState extends ConsumerState<_LocationLabel> {
  static const _movedThresholdMeters = 40.0;

  String? _label;
  bool _loading = false;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = false;
    });

    try {
      var perm =
          await Geolocator.checkPermission().timeout(const Duration(seconds: 3));
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        if (mounted) setState(() => _error = true);
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );

      final marks = await placemarkFromCoordinates(pos.latitude, pos.longitude)
          .timeout(const Duration(seconds: 6));
      String? label;
      if (marks.isNotEmpty) {
        final m = marks.first;
        if (m.thoroughfare != null && m.thoroughfare!.isNotEmpty) {
          label = m.thoroughfare;
        } else if (m.subLocality != null && m.subLocality!.isNotEmpty) {
          label = m.subLocality;
        } else if (m.locality != null && m.locality!.isNotEmpty) {
          label = m.locality;
        }
      }

      if (!mounted) return;
      setState(() {
        _label = label;
        _error = label == null;
      });

      // Push to the backend only if this fix meaningfully differs from the
      // background tracker's last synced position — avoids spamming an
      // update for a worker who hasn't actually moved.
      final tracker = ref.read(locationTrackerProvider);
      final movedMeaningfully = tracker.lastSyncedLat == null ||
          tracker.lastSyncedLng == null ||
          Geolocator.distanceBetween(
                tracker.lastSyncedLat!,
                tracker.lastSyncedLng!,
                pos.latitude,
                pos.longitude,
              ) >
              _movedThresholdMeters;
      if (movedMeaningfully) {
        await ref
            .read(workerRepositoryProvider)
            .updateLocationOnly(lat: pos.latitude, lng: pos.longitude);
      }
    } catch (_) {
      if (mounted) setState(() => _error = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = _loading
        ? context.l10n.workerLocating
        : _error
            ? context.l10n.workerTapToRetry
            : (_label ?? context.l10n.workerTapForLocation);

    return GestureDetector(
      onTap: _refresh,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 110),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_loading)
              const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: _kOrange,
                ),
              )
            else
              Icon(
                _error
                    ? Icons.location_off_outlined
                    : Icons.location_on_rounded,
                size: 14,
                color: _error ? _kGray : _kOrange,
              ),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _error ? _kGray : _kDark,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Hero Card ─────────────────────────────────────────────────────────────────

class _HeroCard extends ConsumerWidget {
  final WorkerProfileEntity profile;
  const _HeroCard({required this.profile});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = profile.availabilityStatus;
    final isLoading = ref.watch(availabilityNotifierProvider).isLoading;
    final isOnline = status == AvailabilityStatus.online;
    final isBusy = status == AvailabilityStatus.busy;
    final c = context.semanticColors;

    // The prototype has no navy card and no glow. Its Home opens on a plain
    // white card carrying exactly what this one carries — availability status
    // plus the toggle (prototype lines 301–308) — so that is what this card
    // now is. Its one dark card (`--deep`, lines 329–338) belongs to a *live
    // job*, which this card never shows.
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, _gap, 20, 0),
      child: Container(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(_rCard),
          border: Border.all(color: c.border),
        ),
        child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status row + toggle
                  Row(
                    children: [
                      Container(
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(
                          color: isBusy
                              ? c.warning
                              : isOnline
                                  ? c.success
                                  : c.textSecondary,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isBusy
                            ? context.l10n.workerOnActiveJob
                            : isOnline
                                ? context.l10n.workerOnline
                                : context.l10n.workerOffline,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: isBusy
                              ? c.warning
                              : isOnline
                                  ? c.success
                                  : c.textSecondary,
                        ),
                      ),
                      const Spacer(),
                      if (!isBusy)
                        _HeroToggleBtn(
                          label: isLoading
                              ? (isOnline
                                  ? context.l10n.workerGoingOffline
                                  : context.l10n.workerConnecting)
                              : (isOnline
                                  ? context.l10n.workerGoOffline
                                  : context.l10n.workerGoOnline),
                          isOnline: isOnline,
                          loading: isLoading,
                          locked: !isOnline && !profile.isOnboardingApproved,
                          onTap: () => isOnline
                              ? _handleGoOffline(context, ref)
                              : _handleGoOnline(context, ref),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Earnings. This used to be a Roman-Urdu headline with a
                  // small English gloss underneath — the app now speaks one
                  // language at a time, so the gloss line is gone.
                  Text(
                    context.l10n.workerTodaysEarnings,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: c.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Prototype `.big` (CSS line 44) — 23px / 700. The money
                  // figure on its Home card is the same size.
                  Text(
                    formatPkr(profile.stats.todayEarnings),
                    style: TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.w700,
                      color: c.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Stats row
                  Row(
                    children: [
                      _HeroStat(
                        label: context.l10n.bookingStatusCompleted,
                        value: '${profile.stats.completedJobs}',
                        icon: Icons.check_circle_outline_rounded,
                      ),
                      const SizedBox(width: 11),
                      _HeroStat(
                        label: context.l10n.workerRating,
                        value: profile.rating > 0
                            ? profile.rating.toStringAsFixed(1)
                            : '—',
                        icon: Icons.star_outline_rounded,
                      ),
                      const SizedBox(width: 11),
                      _HeroStat(
                        label: context.l10n.workerActive,
                        value: '${profile.stats.activeJobs}',
                        icon: Icons.bolt_rounded,
                      ),
                    ],
                  ),
                ],
              ),
            ),
      ),
    );
  }

  Future<void> _handleGoOnline(BuildContext context, WidgetRef ref) async {
    if (!profile.isOnboardingApproved) {
      // Blocked either way — the backend refuses ONLINE below APPROVED — but
      // a submitted Ustaad is waiting on an admin, not on paperwork.
      _showSnack(
        context,
        profile.isPendingReview
            ? context.l10n.workerPendingReviewBody
            : context.l10n.workerApprovalRequired,
      );
      return;
    }

    // Pre-flight check so a denied permission or disabled GPS shows the
    // specific, actionable message below instead of silently going online
    // with no coordinates and letting the backend's generic validation
    // error surface instead (see LocationTrackerNotifier.startTracking,
    // which is left untouched — this is purely an additional UX gate in
    // front of it).
    final locationCheck = await resolveCurrentLocation();
    if (!locationCheck.isAvailable) {
      if (context.mounted) {
        showLocationRecoverySnack(
          context,
          locationCheck.status,
          onRetry: () => _handleGoOnline(context, ref),
        );
      }
      return;
    }

    if (!context.mounted) return;
    final result =
        await ref.read(availabilityNotifierProvider.notifier).goOnline();
    if (result == AvailabilityToggleResult.needsSkills && context.mounted) {
      await showSkillsSheet(context, ref);
    } else if (context.mounted) {
      final err = ref.read(availabilityNotifierProvider).error;
      if (err != null) _showSnack(context, failureMessage(context.l10n, err));
    }
  }

  Future<void> _handleGoOffline(BuildContext context, WidgetRef ref) async {
    final c = context.semanticColors;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(context.l10n.workerGoOfflineConfirmTitle,
            style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 18,
                color: c.textPrimary)),
        content: Text(context.l10n.workerGoOfflineConfirmBody,
            style: TextStyle(fontSize: 14, color: c.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.l10n.commonCancel,
                style: TextStyle(color: c.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: c.primary,
              foregroundColor: c.onPrimary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(_rButton)),
              elevation: 0,
            ),
            child: Text(context.l10n.workerGoOfflineConfirmYes),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await ref.read(availabilityNotifierProvider.notifier).goOffline();
      if (context.mounted) {
        final err = ref.read(availabilityNotifierProvider).error;
        if (err != null) _showSnack(context, failureMessage(context.l10n, err));
      }
    }
  }

  void _showSnack(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }
}

class _HeroToggleBtn extends StatelessWidget {
  final String label;
  final bool isOnline;
  final bool loading;
  final bool locked;
  final VoidCallback onTap;
  const _HeroToggleBtn({
    required this.label,
    required this.isOnline,
    required this.loading,
    this.locked = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;
    // Online = the quiet state (nothing to do), so it reads as an outlined
    // control; offline = the filled brand button that invites the tap. Both
    // sit on `c.surface` now that the card is white.
    final fg = isOnline ? c.textPrimary : c.onPrimary;

    return GestureDetector(
      onTap: loading ? null : onTap,
      child: Opacity(
        opacity: locked ? 0.5 : 1,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          constraints: const BoxConstraints(minHeight: 44),
          decoration: BoxDecoration(
            color: isOnline ? c.surfaceSubtle : c.primary,
            borderRadius: BorderRadius.circular(_rPill),
            border: isOnline ? Border.all(color: c.controlBorder) : null,
          ),
          child: loading
              ? SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: fg,
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (locked) ...[
                      Icon(Icons.lock_outline_rounded, size: 13, color: fg),
                      const SizedBox(width: 4),
                    ],
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: fg,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _HeroStat({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
        decoration: BoxDecoration(
          color: c.surfaceSubtle,
          // No prototype equivalent for a tile nested inside a card; taking
          // the button radius rather than inventing a third value.
          borderRadius: BorderRadius.circular(_rButton),
          border: Border.all(color: c.border),
        ),
        child: Column(
          children: [
            Icon(icon, size: 17, color: c.primary),
            const SizedBox(height: 5),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: c.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                color: c.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── View New Jobs CTA ─────────────────────────────────────────────────────────

class _NewJobsCta extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, _gap, 20, 0),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () => context.go('/worker/new-jobs'),
          icon: const Icon(Icons.work_outline_rounded, size: 19),
          label: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                context.l10n.workerFindNewWork,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              Text(
                context.l10n.workerViewNewJobs,
                style:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w400),
              ),
            ],
          ),
          // Prototype `.btnp` (CSS line 48): radius 14, min-height 52,
          // 16px/700, no shadow.
          style: ElevatedButton.styleFrom(
            backgroundColor: c.primary,
            foregroundColor: c.onPrimary,
            elevation: 0,
            minimumSize: const Size.fromHeight(_hButton),
            padding: const EdgeInsets.symmetric(vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(_rButton),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Today Section ─────────────────────────────────────────────────────────────

class _TodaySection extends StatelessWidget {
  final WorkerProfileEntity profile;
  const _TodaySection({required this.profile});

  @override
  Widget build(BuildContext context) {
    final job = profile.ongoingJob;
    final c = context.semanticColors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, _gap, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _SectionHeading(context.l10n.commonToday),
              const Spacer(),
              GestureDetector(
                onTap: () => context.go('/worker/jobs'),
                // Same wording as the Client "My Jobs" screen title. The
                // bottom-nav tab of the same name stays hard-coded English.
                child: Text(
                  context.l10n.clientJobsTitle,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: c.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          job != null
              ? _ActiveJobCard(job: job)
              : _NoJobCard(),
        ],
      ),
    );
  }
}

class _ActiveJobCard extends StatelessWidget {
  final OngoingJobEntity job;
  const _ActiveJobCard({required this.job});

  @override
  Widget build(BuildContext context) {
    // A booking whose status is ACCEPTED has been *assigned* to this Ustaad,
    // whichever lane it came from — direct standard hire, inspection, or an
    // accepted bid. "Accepted" used to be shown here for the non-inspection
    // lanes only because this card carried its own copy of the mapping; the
    // shared helper is the same one My Jobs and the client app already use,
    // so the wording can no longer differ between screens.
    final c = context.semanticColors;
    final statusLabel = ongoingJobStatusLabel(context.l10n, job.status);
    final statusColor = _statusColor(c, job.status);

    return GestureDetector(
      onTap: () => context.push('/worker/job/${job.id}'),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(_rCard),
          border: Border.all(color: c.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: c.textSecondary,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                // Prototype `.sec` treatment: this is a section label, and
                // there it is `--ink2`, not an accent colour.
                Text(
                  context.l10n.workerActiveJobCaps,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: c.textSecondary,
                    letterSpacing: 0.75,
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _statusSurface(c, job.status),
                    borderRadius: BorderRadius.circular(_rPill),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              job.title ?? job.categoryName,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: c.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.location_on_rounded,
                    size: 14, color: c.textSecondary),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    job.clientArea,
                    style: TextStyle(fontSize: 14, color: c.textSecondary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            // Price this Ustaad was hired for — OngoingJobEntity.displayPrice
            // is the same canonicalWorkPrice rule as My Jobs and Track
            // Worker, so this card can never disagree with them. Never an
            // "estimate": HandyGo has no estimated-price concept.
            if (job.displayPrice != null) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.payments_outlined,
                      size: 14, color: c.textSecondary),
                  const SizedBox(width: 4),
                  Text(
                    formatPkr(job.displayPrice),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: c.textPrimary,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  onTap: () =>
                      context.push('/worker/job/${job.id}?openMap=true'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: c.softTeal,
                      borderRadius: BorderRadius.circular(_rPill),
                      border: Border.all(color: c.primary),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.map_outlined, size: 15, color: c.primary),
                        const SizedBox(width: 5),
                        Text(
                          context.l10n.workerMap,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: c.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Text(
                  context.l10n.workerViewDetails,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: c.primary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Status → token. The branches are untouched; only the colour each one
  /// returns has moved onto the palette. The pairings mirror the prototype's
  /// `.tg` variants (CSS lines 74–78), which always pair a foreground with
  /// its own tint: `.tg.a` teal, `.tg.w` urgent, `.tg.g` sage, plain `.tg`
  /// muted.
  Color _statusColor(AppSemanticColors c, String status) {
    switch (status.toUpperCase()) {
      case 'ACCEPTED':
        return c.primary;
      case 'EN_ROUTE':
        return c.warning;
      case 'IN_PROGRESS':
        return c.success;
      default:
        return c.textSecondary;
    }
  }

  /// The tint that pairs with [_statusColor] — same branches, background side.
  Color _statusSurface(AppSemanticColors c, String status) {
    switch (status.toUpperCase()) {
      case 'ACCEPTED':
        return c.softTeal;
      case 'EN_ROUTE':
        return c.warningSurface;
      case 'IN_PROGRESS':
        return c.successSoft;
      default:
        return c.surfaceSubtle;
    }
  }
}

class _NoJobCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(_rCard),
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          // Prototype `.icb` (CSS line 89): a 46px circle, not a rounded box.
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: c.surfaceSubtle,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.inbox_outlined, color: c.textSecondary, size: 22),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.workerNoActiveJob,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: c.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  context.l10n.workerStayOnlineHint,
                  style: TextStyle(fontSize: 14, color: c.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // Prototype `.tg.g` (CSS line 75): sage tint behind sage text.
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: c.successSoft,
              borderRadius: BorderRadius.circular(_rPill),
            ),
            child: Text(
              context.l10n.workerReady,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: c.success,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Performance Section ───────────────────────────────────────────────────────

class _PerformanceSection extends StatelessWidget {
  final WorkerProfileEntity profile;
  const _PerformanceSection({required this.profile});

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, _gap, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeading(context.l10n.workerPerformance),
          const SizedBox(height: 9),
          Row(
            children: [
              _PerfCard(
                label: context.l10n.workerJobsDone,
                value: '${profile.stats.completedJobs}',
                icon: Icons.check_circle_outline_rounded,
                iconColor: c.success,
                iconSurface: c.successSoft,
              ),
              const SizedBox(width: 11),
              _PerfCard(
                label: context.l10n.workerCancelRate,
                value: context.l10n
                    .workerPercentValue('${profile.stats.cancellationRate}'),
                icon: Icons.cancel_outlined,
                // `urgent`, not `error`: the token file draws that line
                // explicitly ("urgent is not a failure"), and a cancellation
                // rate is a number that wants attention, not a failed
                // operation. Using `error` here would also need an
                // `errorSoft` tint that does not exist — and inventing one
                // for a metric that is not an error would be the wrong
                // reason to add a token.
                iconColor: c.urgent,
                iconSurface: c.urgentSoft,
              ),
              const SizedBox(width: 11),
              _PerfCard(
                label: context.l10n.workerResponse,
                value: profile.stats.responseLabel ?? '—',
                icon: Icons.bolt_rounded,
                iconColor: c.warning,
                iconSurface: c.warningSurface,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PerfCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;

  /// The tint the icon sits on. Passed in as a token rather than derived with
  /// `iconColor.withValues(alpha: …)`: a colour is taken from the palette, not
  /// computed.
  final Color iconSurface;
  const _PerfCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
    required this.iconSurface,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(_rCard),
          border: Border.all(color: c.border),
        ),
        child: Column(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconSurface,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 18, color: iconColor),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: c.textPrimary,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(fontSize: 12.5, color: c.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Reviews section ───────────────────────────────────────────────────────────

class _ReviewsSection extends ConsumerWidget {
  final WorkerProfileEntity profile;
  const _ReviewsSection({required this.profile});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviewsAsync = ref.watch(workerRecentReviewsProvider);
    final c = context.semanticColors;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, _gap, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _SectionHeading(context.l10n.workerReviews),
              if (profile.totalRatings > 0) ...[
                const SizedBox(width: 8),
                Icon(Icons.star_rounded, size: 15, color: c.warning),
                const SizedBox(width: 3),
                Text(
                  '${profile.rating.toStringAsFixed(1)} · ${profile.totalRatings}',
                  style: TextStyle(fontSize: 12.5, color: c.textSecondary),
                ),
              ],
              const Spacer(),
              if (profile.totalRatings > 0)
                GestureDetector(
                  onTap: () => context.push('/worker/reviews'),
                  child: Text(
                    context.l10n.workerSeeAll,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: c.primary,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 9),
          reviewsAsync.when(
            loading: () => SizedBox(
              height: 20,
              width: 20,
              child:
                  CircularProgressIndicator(strokeWidth: 2, color: c.primary),
            ),
            error: (e, s) => const SizedBox.shrink(),
            data: (reviews) => reviews.isEmpty
                ? _EmptyReviews()
                : Container(
                    decoration: BoxDecoration(
                      color: c.surface,
                      borderRadius: BorderRadius.circular(_rCard),
                      border: Border.all(color: c.border),
                    ),
                    child: Column(
                      children: reviews
                          .asMap()
                          .entries
                          .map((e) => _ReviewItem(
                                review: e.value,
                                isLast: e.key == reviews.length - 1,
                              ))
                          .toList(),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _EmptyReviews extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(_rCard),
        border: Border.all(color: c.border),
      ),
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: c.warningSurface,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.star_outline_rounded,
              color: c.warning,
              size: 24,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            context.l10n.workerNoReviewsYet,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: c.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            context.l10n.workerReviewsAppearHint,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: c.textSecondary, height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _ReviewItem extends StatelessWidget {
  final WorkerReviewEntity review;
  final bool isLast;
  const _ReviewItem({required this.review, required this.isLast});

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(5, (i) {
                      return Icon(
                        i < review.rating
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        size: 15,
                        color: i < review.rating ? c.warning : c.border,
                      );
                    }),
                  ),
                  const Spacer(),
                  Text(
                    DateFormat('MMM d, yyyy').format(review.createdAt),
                    style: TextStyle(fontSize: 12.5, color: c.textSecondary),
                  ),
                ],
              ),
              if (review.comment != null && review.comment!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  review.comment!,
                  style: TextStyle(
                      fontSize: 14, color: c.textPrimary, height: 1.45),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 6),
              Row(
                children: [
                  Text(
                    review.serviceCategory,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: c.primary,
                    ),
                  ),
                  if (review.clientName != null &&
                      review.clientName!.isNotEmpty) ...[
                    Text('  ·  ',
                        style:
                            TextStyle(fontSize: 13, color: c.textSecondary)),
                    Text(
                      review.clientName!,
                      style: TextStyle(fontSize: 13, color: c.textSecondary),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        if (!isLast) Divider(height: 1, color: c.divider),
      ],
    );
  }
}

// ── Skills bottom sheet ───────────────────────────────────────────────────────

Future<void> showSkillsSheet(BuildContext context, WidgetRef ref) async {
  final profile = ref.read(workerProfileProvider).valueOrNull;
  // Only one main skill is allowed — pre-select just the first existing one
  // (legacy profiles saved before this rule may carry more than one; opening
  // the sheet already narrows the working selection down to a single skill).
  final existingId = profile?.skills.isNotEmpty == true
      ? profile!.skills.first.categoryId
      : null;
  ref.read(selectedCategoryIdsProvider.notifier).state =
      existingId != null ? {existingId} : {};

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => ProviderScope(
      parent: ProviderScope.containerOf(context),
      child: const _SkillsSheet(),
    ),
  );
}

class _SkillsSheet extends ConsumerWidget {
  const _SkillsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(categoriesProvider);
    final selected = ref.watch(selectedCategoryIdsProvider);
    final isSaving = ref.watch(skillsNotifierProvider).isLoading;
    final c = context.semanticColors;

    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: c.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.workerSelectMainSkill,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: c.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  context.l10n.workerSelectMainSkillHint,
                  style: TextStyle(fontSize: 14, color: c.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          categoriesAsync.when(
            loading: () => Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                  child: CircularProgressIndicator(color: c.primary)),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.all(24),
              child: Text(context.l10n.workerCategoriesLoadFailed('$e')),
            ),
            data: (categories) => _CategoryChips(
              categories: categories,
              selected: selected,
              // Single-select: choosing a category always replaces the
              // current selection (radio-button semantics) rather than
              // toggling membership — a worker may have only one main skill.
              onToggle: (id) {
                ref.read(selectedCategoryIdsProvider.notifier).state = {id};
              },
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (isSaving || selected.isEmpty)
                    ? null
                    : () async {
                        final saved = await ref
                            .read(skillsNotifierProvider.notifier)
                            .saveSkills(selected.toList());
                        if (!context.mounted) return;
                        if (saved) {
                          Navigator.pop(context);
                          await ref
                              .read(availabilityNotifierProvider.notifier)
                              .goOnline();
                        } else {
                          final err =
                              ref.read(skillsNotifierProvider).error;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(err == null
                                  ? context.l10n.workerSkillsSaveFailed
                                  : failureMessage(context.l10n, err,
                                      fallback: context.l10n.workerSkillsSaveFailed)),
                              behavior: SnackBarBehavior.floating,
                              backgroundColor: c.error,
                            ),
                          );
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: c.primary,
                  foregroundColor: c.onPrimary,
                  disabledBackgroundColor: c.surfaceSubtle,
                  disabledForegroundColor: c.textSecondary,
                  elevation: 0,
                  minimumSize: const Size.fromHeight(_hButton),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(_rButton),
                  ),
                ),
                child: isSaving
                    ? SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: c.onPrimary,
                        ),
                      )
                    : Text(
                        selected.isEmpty
                            ? context.l10n.workerSelectMainSkill
                            : context.l10n.workerSaveAndGoOnline,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryChips extends StatelessWidget {
  final List<CategoryEntity> categories;
  final Set<String> selected;
  final void Function(String id) onToggle;

  const _CategoryChips({
    required this.categories,
    required this.selected,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Wrap(
        spacing: 11,
        runSpacing: 11,
        children: categories.map((cat) {
          final isSelected = selected.contains(cat.id);
          return GestureDetector(
            onTap: () => onToggle(cat.id),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              constraints: const BoxConstraints(minHeight: 44),
              alignment: Alignment.center,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected ? c.primary : c.surfaceSubtle,
                borderRadius: BorderRadius.circular(_rPill),
                border: Border.all(
                  color: isSelected ? c.primary : c.border,
                ),
              ),
              child: Text(
                cat.name,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? c.onPrimary : c.textSecondary,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Error view ────────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off_rounded, size: 48, color: c.textSecondary),
            const SizedBox(height: 12),
            Text(
              context.l10n.workerDashboardLoadFailed,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: c.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: c.textSecondary),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 19),
              label: Text(context.l10n.commonRetry,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: c.primary,
                foregroundColor: c.onPrimary,
                elevation: 0,
                minimumSize: const Size(0, _hButton),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(_rButton),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
