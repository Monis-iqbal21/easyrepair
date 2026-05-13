import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../notifications/domain/entities/notification_entity.dart';
import '../../../notifications/presentation/providers/notification_providers.dart';
import '../../../../core/presentation/responsive_utils.dart';
import '../widgets/client_bottom_nav_bar.dart';
import '../widgets/service_card.dart';
import '../widgets/service_data.dart';

const _kGreen = Color(0xFF1D9E75);
const _kDark = Color(0xFF1A1A1A);
const _kGray = Color(0xFF6B7280);

class ClientHomePage extends ConsumerWidget {
  const ClientHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final user = authState.valueOrNull;
    final firstName = user?.firstName ?? 'there';
    final screenWidth = MediaQuery.sizeOf(context).width;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // ── Branding header ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  // App logo
                  Image.asset(
                    'assets/images/logo-green.png',
                    height: 36,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => const Icon(
                      Icons.home_repair_service_rounded,
                      color: _kGreen,
                      size: 28,
                    ),
                  ),
                  const Spacer(),
                  // Notification bell with unread badge
                  GestureDetector(
                    onTap: () => context.push('/notifications'),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.07),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.notifications_outlined,
                            size: 20,
                            color: _kDark,
                          ),
                        ),
                        Consumer(
                          builder: (_, cRef, _) {
                            final count =
                                cRef
                                    .watch(unreadNotificationCountProvider)
                                    .valueOrNull ??
                                0;
                            if (count == 0) return const SizedBox.shrink();
                            return Positioned(
                              top: -2,
                              right: -2,
                              child: Container(
                                width: 16,
                                height: 16,
                                decoration: BoxDecoration(
                                  color: _kGreen,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 1.5,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    count > 9 ? '9+' : '$count',
                                    style: const TextStyle(
                                      fontSize: 8,
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Scrollable content ────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Greeting ─────────────────────────────────────────
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hi $firstName 👋',
                          style: TextStyle(
                            fontSize: rFont(
                              screenWidth,
                              22,
                              min: 18,
                              max: 26,
                            ),
                            fontWeight: FontWeight.w700,
                            color: _kDark,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'What do you need fixed today?',
                          style: TextStyle(
                            fontSize: rFont(
                              screenWidth,
                              13,
                              min: 11,
                              max: 15,
                            ),
                            color: _kGray,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // ── Search bar ────────────────────────────────────────
                    GestureDetector(
                      onTap: () => context.push('/client/post-job'),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.search_rounded,
                              color: Color(0xFF94A3B8),
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Search services or describe issue...',
                                style: TextStyle(
                                  fontSize: rFont(
                                    screenWidth,
                                    14,
                                    min: 12,
                                    max: 16,
                                  ),
                                  color: const Color(0xFF94A3B8),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ── EasyRepair Guarantee banner ───────────────────────
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: _kGreen,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.verified_user_outlined,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Handygo Guarantee',
                                  style: TextStyle(
                                    fontSize: rFont(
                                      screenWidth,
                                      15,
                                      min: 13,
                                      max: 17,
                                    ),
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  'Verified workers · Fixed prices · Free re-work',
                                  style: TextStyle(
                                    fontSize: rFont(
                                      screenWidth,
                                      12,
                                      min: 10,
                                      max: 13,
                                    ),
                                    color: Colors.white.withValues(alpha: 0.85),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ── Our Services ──────────────────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Our Services',
                          style: TextStyle(
                            fontSize: rFont(screenWidth, 20, min: 17, max: 23),
                            fontWeight: FontWeight.w700,
                            color: _kDark,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => context.push('/client/post-job'),
                          child: Text(
                            'See all',
                            style: TextStyle(
                              fontSize: rFont(
                                screenWidth,
                                13,
                                min: 11,
                                max: 15,
                              ),
                              fontWeight: FontWeight.w500,
                              color: _kGreen,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    LayoutBuilder(
                      builder: (context, constraints) {
                        const crossAxisCount = 2;
                        const crossAxisSpacing = 12.0;
                        const mainAxisSpacing = 12.0;
                        const cardBaseW = 170.0;

                        final cardWidth =
                            (constraints.maxWidth -
                                ((crossAxisCount - 1) * crossAxisSpacing)) /
                            crossAxisCount;

                        final imageHeight = cardWidth / 1.6;

                        final titleSize = rFont(
                          cardWidth,
                          15,
                          min: 13,
                          max: 17,
                          baseWidth: cardBaseW,
                        );
                        final btnSize = rFont(
                          cardWidth,
                          11,
                          min: 10,
                          max: 12,
                          baseWidth: cardBaseW,
                        );
                        // padding(top:9 + bottom:9) + title + gap(6)
                        // + "Book Now" pill (3+btnSize+3) + 6px buffer.
                        final textAreaHeight =
                            18.0 +
                            titleSize * 1.6 +
                            6.0 +
                            (btnSize + 6) +
                            6.0;

                        final cardHeight = imageHeight + textAreaHeight;
                        final childAspectRatio = cardWidth / cardHeight;

                        return GridView.builder(
                          itemCount: kServices.length,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: crossAxisCount,
                                crossAxisSpacing: crossAxisSpacing,
                                mainAxisSpacing: mainAxisSpacing,
                                childAspectRatio: childAspectRatio,
                              ),
                          itemBuilder: (context, index) {
                            final s = kServices[index];
                            return ServiceCard(
                              title: s.title,
                              emoji: s.emoji,
                              backgroundColor: s.bg,
                              emojiBackgroundColor: s.emojiBg,
                              imagePath: s.imagePath,
                              onTap: () => context.push(
                                '/client/post-job?service=${Uri.encodeComponent(s.title)}',
                              ),
                            );
                          },
                        );
                      },
                    ),

                    const SizedBox(height: 10),

                    // ── Recent Notifications ──────────────────────────────
                    const _RecentNotifications(),

                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      extendBody: true,
      bottomNavigationBar: const ClientBottomNavBar(currentIndex: 0),
    );
  }
}

// ── Recent notifications strip ────────────────────────────────────────────────

class _RecentNotifications extends ConsumerWidget {
  const _RecentNotifications();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(notificationsProvider);
    final screenWidth = MediaQuery.sizeOf(context).width;

    return async.maybeWhen(
      data: (all) {
        if (all.isEmpty) return const SizedBox.shrink();
        final items = all.take(4).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recent',
                  style: TextStyle(
                    fontSize: rFont(screenWidth, 18, min: 15, max: 21),
                    fontWeight: FontWeight.w700,
                    color: _kDark,
                  ),
                ),
                GestureDetector(
                  onTap: () => context.push('/notifications'),
                  child: Text(
                    'See all',
                    style: TextStyle(
                      fontSize: rFont(screenWidth, 13, min: 11, max: 15),
                      fontWeight: FontWeight.w500,
                      color: _kGreen,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...items.map((n) => _CompactNotifTile(n)),
          ],
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}

class _CompactNotifTile extends StatelessWidget {
  final NotificationEntity n;
  const _CompactNotifTile(this.n);

  @override
  Widget build(BuildContext context) {
    final isUnread = !n.isRead;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: () {
          if (n.route != null && n.route!.isNotEmpty) {
            context.push(n.route!);
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isUnread ? const Color(0xFFF0FDF4) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isUnread
                  ? _kGreen.withValues(alpha: 0.2)
                  : const Color(0xFFE2E8F0),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: isUnread
                      ? _kGreen.withValues(alpha: 0.12)
                      : const Color(0xFFF1F5F9),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.notifications_outlined,
                  size: 17,
                  color: isUnread ? _kGreen : _kGray,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      n.title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight:
                            isUnread ? FontWeight.w600 : FontWeight.w500,
                        color: _kDark,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      n.body,
                      style: const TextStyle(fontSize: 12, color: _kGray),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _fmt(n.createdAt),
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _fmt(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return DateFormat('MMM d').format(dt);
  }
}
