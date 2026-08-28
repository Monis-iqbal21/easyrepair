import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/failure_messages.dart';
import '../../../../core/l10n/l10n_extensions.dart';
import '../../../../core/network/offline_banner.dart';
import '../../../../core/network/reconnect_refresh.dart';
import '../../../../core/theme/app_semantic_colors.dart';
import '../../domain/entities/booking_entity.dart';
import '../providers/booking_providers.dart';
import '../utils/booking_labels.dart';
import '../widgets/booking_card.dart';
import '../widgets/booking_skeleton.dart';
import '../widgets/client_cancel_reason_sheet.dart';
import '../widgets/cash_payment_confirmation_card.dart';
import 'choose_ustaad_page.dart';
import 'track_worker_page.dart';
import 'worker_discovery_map_page.dart';

class MyBookingsPage extends ConsumerStatefulWidget {
  const MyBookingsPage({super.key});

  @override
  ConsumerState<MyBookingsPage> createState() => _MyBookingsPageState();
}

class _MyBookingsPageState extends ConsumerState<MyBookingsPage> {
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) ref.read(bookingsNotifierProvider.notifier).refresh();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    refreshOnReconnect(
      ref,
      () => ref.read(bookingsNotifierProvider.notifier).refresh(),
    );
    final colors = context.semanticColors;
    final bookingsAsync = ref.watch(bookingsNotifierProvider);
    final filter = ref.watch(bookingFilterProvider);
    final filtered = ref.watch(filteredBookingsProvider);
    final isShowingCachedData =
        ref.watch(bookingsIsOfflineProvider) && bookingsAsync.hasValue;
    BookingEntity? paymentPromptBooking;
    for (final booking
        in bookingsAsync.valueOrNull ?? const <BookingEntity>[]) {
      if (booking.canClientConfirmCash) {
        paymentPromptBooking = booking;
        break;
      }
    }
    if (!isShowingCachedData && paymentPromptBooking != null) {
      scheduleAutomaticCashPaymentPrompt(context, ref, paymentPromptBooking);
    }

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _Header(),
            _StatusTabs(activeTab: filter.activeTab),
            const SizedBox(height: 10),
            if (isShowingCachedData) const OfflineDataBanner(),
            if (bookingsAsync.hasError && bookingsAsync.hasValue)
              const _RefreshFailedBanner(),
            Expanded(
              child: bookingsAsync.when(
                skipError: true,
                loading: () => const Padding(
                  padding: EdgeInsets.fromLTRB(16, 4, 16, 0),
                  child: BookingSkeleton(),
                ),
                error: (error, _) => _ErrorState(
                  message: failureMessage(
                    context.l10n,
                    error,
                    fallback: context.l10n.myBookingsLoadFailed,
                  ),
                  onRetry: () =>
                      ref.read(bookingsNotifierProvider.notifier).refresh(),
                ),
                data: (_) => filtered.isEmpty
                    ? _EmptyState(
                        activeTab: filter.activeTab,
                        hasExtraFilters:
                            filter.searchQuery.isNotEmpty ||
                            filter.hasActiveFilters,
                      )
                    : RefreshIndicator(
                        color: colors.primary,
                        backgroundColor: colors.surface,
                        onRefresh: () => ref
                            .read(bookingsNotifierProvider.notifier)
                            .refresh(),
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 110),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final booking = filtered[index];
                            return BookingCard(
                              key: ValueKey(booking.id),
                              booking: booking,
                              onTap: () =>
                                  context.push('/client/booking/${booking.id}'),
                              onCancel: booking.canClientCancel
                                  ? () => _confirmCancel(context, ref, booking)
                                  : null,
                              onChat: booking.assignedWorker != null
                                  ? () => context.push('/client/chat')
                                  : null,
                              onEdit:
                                  booking.status == BookingStatus.pending &&
                                      booking.assignedWorker == null
                                  ? () => context.push(
                                      '/client/post-job?editId=${booking.id}',
                                    )
                                  : null,
                              onFindWorkers: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      booking.lane == BookingLane.bidding
                                      ? WorkerDiscoveryMapPage(booking: booking)
                                      : ChooseUstaadPage(booking: booking),
                                ),
                              ),
                              onTrackWorker:
                                  booking.assignedWorker != null &&
                                      booking.status !=
                                          BookingStatus.completed &&
                                      booking.status !=
                                          BookingStatus.cancelled &&
                                      booking.status != BookingStatus.rejected
                                  ? () => Navigator.of(context).push(
                                      MaterialPageRoute<void>(
                                        builder: (_) => TrackWorkerPage(
                                          bookingId: booking.id,
                                        ),
                                      ),
                                    )
                                  : null,
                              onConfirmCash: booking.canClientConfirmCash
                                  ? () => ref
                                        .read(
                                          cashPaymentPromptControllerProvider,
                                        )
                                        .showForBooking(context, booking)
                                  : null,
                            );
                          },
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmCancel(
    BuildContext context,
    WidgetRef ref,
    BookingEntity booking,
  ) async {
    try {
      await showClientCancelReasonSheet(
        context: context,
        hasAssignedWorker: booking.assignedWorker != null,
        onSubmit: (reason) => ref
            .read(bookingsNotifierProvider.notifier)
            .cancelBooking(booking.id, reason),
      );
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              failureMessage(
                context.l10n,
                error,
                fallback: context.l10n.bookingCancelFailed,
              ),
            ),
          ),
        );
      }
    }
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.navBookings,
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 26,
              height: 1.15,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            context.l10n.myBookingsSubtitle,
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 13,
              height: 1.3,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusTabs extends ConsumerWidget {
  final BookingTab activeTab;

  const _StatusTabs({required this.activeTab});

  static const _tabs = [
    BookingTab.all,
    BookingTab.live,
    BookingTab.completed,
    BookingTab.cancelled,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.semanticColors;
    final allBookings = ref.watch(bookingsNotifierProvider).valueOrNull ?? [];
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _tabs.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final tab = _tabs[index];
          final selected = tab == activeTab;
          final count = allBookings
              .where((booking) => bookingMatchesClientTab(booking, tab))
              .length;
          return Material(
            color: selected ? colors.primary : colors.surface,
            shape: StadiumBorder(
              side: BorderSide(
                color: selected ? colors.primary : colors.border,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => ref.read(bookingFilterProvider.notifier).setTab(tab),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      bookingTabLabel(
                        context.l10n,
                        tab,
                        romanUrdu:
                            Localizations.localeOf(context).scriptCode ==
                            'Latn',
                      ),
                      style: TextStyle(
                        color: selected
                            ? colors.onPrimary
                            : colors.textSecondary,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (count > 0) ...[
                      const SizedBox(width: 6),
                      Container(
                        constraints: const BoxConstraints(minWidth: 18),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: selected
                              ? colors.onPrimary.withValues(alpha: 0.18)
                              : colors.surfaceSubtle,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$count',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: selected
                                ? colors.onPrimary
                                : colors.textSecondary,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final BookingTab activeTab;
  final bool hasExtraFilters;

  const _EmptyState({required this.activeTab, required this.hasExtraFilters});

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;
    final (title, helper) = _copy(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(32, 24, 32, 110),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: colors.softTeal,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.receipt_long_outlined,
                size: 32,
                color: colors.primary,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              helper,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: 13,
                height: 1.45,
              ),
            ),
            if (!hasExtraFilters &&
                (activeTab == BookingTab.all ||
                    activeTab == BookingTab.live)) ...[
              const SizedBox(height: 22),
              FilledButton(
                onPressed: () => context.go('/client/home'),
                style: FilledButton.styleFrom(
                  backgroundColor: colors.primary,
                  foregroundColor: colors.onPrimary,
                  minimumSize: const Size(0, 48),
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(context.l10n.myBookingsEmptyCta),
              ),
            ],
          ],
        ),
      ),
    );
  }

  (String, String) _copy(BuildContext context) {
    if (hasExtraFilters) {
      return (
        context.l10n.myBookingsNoResults,
        context.l10n.myBookingsAdjustFilters,
      );
    }
    return switch (activeTab) {
      BookingTab.live => (
        context.l10n.myBookingsEmptyActiveTitle,
        context.l10n.myBookingsEmptyActiveHelper,
      ),
      BookingTab.completed => (
        context.l10n.myBookingsEmptyCompletedTitle,
        context.l10n.myBookingsEmptyHistoryHelper,
      ),
      BookingTab.cancelled => (
        context.l10n.myBookingsEmptyCancelledTitle,
        context.l10n.myBookingsEmptyHistoryHelper,
      ),
      BookingTab.all || BookingTab.assigned => (
        context.l10n.myBookingsEmptyTitle,
        context.l10n.myBookingsEmptyHistoryHelper,
      ),
    };
  }
}

class _RefreshFailedBanner extends StatelessWidget {
  const _RefreshFailedBanner();

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;
    return Container(
      width: double.infinity,
      color: colors.warningSurface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        context.l10n.myBookingsRefreshFailed,
        style: TextStyle(color: colors.warning, fontSize: 12),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, size: 42, color: colors.error),
            const SizedBox(height: 14),
            Text(
              context.l10n.myBookingsSomethingWrong,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 18),
            OutlinedButton(
              onPressed: onRetry,
              child: Text(context.l10n.commonRetry),
            ),
          ],
        ),
      ),
    );
  }
}
