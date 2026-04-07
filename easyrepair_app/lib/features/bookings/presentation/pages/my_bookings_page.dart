import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/failures.dart';
import '../../../../features/auth/presentation/providers/auth_providers.dart';
import '../../../../features/client/presentation/widgets/client_bottom_nav_bar.dart';
import '../../domain/entities/booking_entity.dart';
import '../providers/booking_providers.dart';
import '../widgets/booking_card.dart';
import '../widgets/booking_filter_sheet.dart';
import '../widgets/booking_search_bar.dart';
import '../widgets/booking_skeleton.dart';

class MyBookingsPage extends ConsumerWidget {
  const MyBookingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookingsAsync = ref.watch(bookingsNotifierProvider);
    final filter = ref.watch(bookingFilterProvider);
    final filtered = ref.watch(filteredBookingsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _Header(filter: filter),
            _StatusTabs(activeTab: filter.activeTab),
            Expanded(
              child: bookingsAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.fromLTRB(16, 4, 16, 0),
                  child: BookingSkeleton(),
                ),
                error: (err, _) => _ErrorState(
                  message: err is Failure
                      ? err.message
                      : 'Unable to load your bookings. Please try again.',
                  onRetry: () =>
                      ref.read(bookingsNotifierProvider.notifier).refresh(),
                ),
                data: (_) => filtered.isEmpty
                    ? _EmptyState(
                        isFiltered: filter.searchQuery.isNotEmpty ||
                            filter.activeTab != BookingTab.all ||
                            filter.hasActiveFilters,
                      )
                    : RefreshIndicator(
                        color: const Color(0xFFFF5F15),
                        backgroundColor: Colors.white,
                        onRefresh: () => ref
                            .read(bookingsNotifierProvider.notifier)
                            .refresh(),
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 110),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final booking = filtered[index];
                            return BookingCard(
                              booking: booking,
                              onTap: () =>
                                  context.push('/client/booking/${booking.id}'),
                              onCancel: booking.status == BookingStatus.pending &&
                                      booking.assignedWorker == null
                                  ? () => _confirmCancel(
                                        context,
                                        ref,
                                        booking,
                                      )
                                  : null,
                              onChat: booking.assignedWorker != null
                                  ? () => context.push('/client/chat')
                                  : null,
                              onEdit: booking.status == BookingStatus.pending &&
                                      booking.assignedWorker == null
                                  ? () => context.push(
                                        '/client/post-job?editId=${booking.id}',
                                      )
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
      extendBody: true,
      bottomNavigationBar: const ClientBottomNavBar(currentIndex: 1),
    );
  }

  Future<void> _confirmCancel(
    BuildContext context,
    WidgetRef ref,
    BookingEntity booking,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text(
          'Cancel Booking?',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: Color(0xFF1A1A1A),
            fontSize: 16,
          ),
        ),
        content: Text(
          'Cancel ${booking.serviceCategory} request ${booking.referenceId}?',
          style: const TextStyle(color: Color(0xFF6B7280), fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Keep it',
              style: TextStyle(color: Color(0xFF6B7280)),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Yes, cancel',
              style: TextStyle(
                color: Color(0xFFDC2626),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        await ref
            .read(bookingsNotifierProvider.notifier)
            .cancelBooking(booking.id);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                e is Failure ? e.message : 'Failed to cancel booking.',
              ),
              backgroundColor: const Color(0xFFDC2626),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      }
    }
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _Header extends ConsumerWidget {
  final BookingFilter filter;

  const _Header({required this.filter});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).valueOrNull;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'My Bookings',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1A1A1A),
                        letterSpacing: -0.3,
                      ),
                    ),
                    if (user != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        '${user.firstName} ${user.lastName}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF94A3B8),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // Total count badge
              Consumer(
                builder: (_, ref, __) {
                  final all = ref
                          .watch(bookingsNotifierProvider)
                          .valueOrNull
                          ?.length ??
                      0;
                  if (all == 0) return const SizedBox.shrink();
                  return Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF5F15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$all total',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 14),
          BookingSearchBar(
            initialValue: filter.searchQuery,
            hasActiveFilters: filter.hasActiveFilters,
            onChanged: (q) => ref
                .read(bookingFilterProvider.notifier)
                .setSearchQuery(q),
            onFilterTap: () => _showFilterSheet(context, ref, filter),
          ),
        ],
      ),
    );
  }

  void _showFilterSheet(
      BuildContext context, WidgetRef ref, BookingFilter current) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BookingFilterSheet(
        currentFilter: current,
        onApply: (updated) {
          ref.read(bookingFilterProvider.notifier).applyFilters(
                urgency: updated.urgency,
                sortOrder: updated.sortOrder,
                hasWorker: updated.hasWorker,
              );
        },
        onReset: () => ref.read(bookingFilterProvider.notifier).resetFilters(),
      ),
    );
  }
}

// ── Status Tabs ───────────────────────────────────────────────────────────────

class _StatusTabs extends ConsumerWidget {
  final BookingTab activeTab;

  const _StatusTabs({required this.activeTab});

  static const _tabs = BookingTab.values;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allBookings =
        ref.watch(bookingsNotifierProvider).valueOrNull ?? [];

    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _tabs.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final tab = _tabs[i];
          final isActive = tab == activeTab;
          final count = tab == BookingTab.all
              ? allBookings.length
              : allBookings
                  .where((b) => b.status.tab == tab)
                  .length;

          return GestureDetector(
            onTap: () =>
                ref.read(bookingFilterProvider.notifier).setTab(tab),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isActive
                    ? const Color(0xFFFF5F15)
                    : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isActive
                      ? const Color(0xFFFF5F15)
                      : const Color(0xFFE2E8F0),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    tab.label,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: isActive
                          ? Colors.white
                          : const Color(0xFF6B7280),
                    ),
                  ),
                  if (count > 0) ...[
                    const SizedBox(width: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: isActive
                            ? Colors.white.withOpacity(0.2)
                            : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$count',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: isActive
                              ? Colors.white
                              : const Color(0xFF6B7280),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final bool isFiltered;
  const _EmptyState({required this.isFiltered});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFFFFF0EB),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Text('📋', style: TextStyle(fontSize: 36)),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              isFiltered ? 'No results found' : 'No bookings yet',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isFiltered
                  ? 'Try adjusting your filters or search term'
                  : 'Book your first service to get started',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF94A3B8),
                height: 1.4,
              ),
            ),
            if (!isFiltered) ...[
              const SizedBox(height: 24),
              GestureDetector(
                onTap: () {
                  // Navigate to home to pick a service
                  // Using context.go('/client/home') — handled via bottom nav
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 13),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF5F15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Text(
                    'Book a Service',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Error state ───────────────────────────────────────────────────────────────

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: const BoxDecoration(
                color: Color(0xFFFFF1F2),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Text('⚠️', style: TextStyle(fontSize: 30)),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Something went wrong',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12.5,
                color: Color(0xFF94A3B8),
                height: 1.4,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: onRetry,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF5F15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Retry',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
