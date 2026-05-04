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

const _kOrange = Color(0xFF1D9E75);
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
            // ── Header ────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hello, $firstName',
                          style: TextStyle(
                            fontSize: rFont(screenWidth, 22, min: 18, max: 26),
                            fontWeight: FontWeight.w700,
                            color: _kDark,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'What do you need fixed today?',
                          style: TextStyle(
                            fontSize: rFont(screenWidth, 13, min: 11, max: 15),
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
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
                                color: Colors.black.withValues(alpha: 0.06),
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

                            if (count == 0) {
                              return const SizedBox.shrink();
                            }

                            return Positioned(
                              top: -2,
                              right: -2,
                              child: Container(
                                width: 16,
                                height: 16,
                                decoration: BoxDecoration(
                                  color: _kOrange,
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

            const SizedBox(height: 24),

            // ── Scrollable content ────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Our Services ─────────────────────────────────
                    Text(
                      'Our Services',
                      style: TextStyle(
                        fontSize: rFont(screenWidth, 20, min: 17, max: 23),
                        fontWeight: FontWeight.w700,
                        color: _kDark,
                      ),
                    ),
                    const SizedBox(height: 14),

                    LayoutBuilder(
                      builder: (context, constraints) {
                        const crossAxisCount = 2;
                        const crossAxisSpacing = 12.0;
                        const mainAxisSpacing = 12.0;
                        // Must match _ImageLayout's rFont baseWidth
                        const cardBaseW = 170.0;

                        final cardWidth =
                            (constraints.maxWidth -
                                ((crossAxisCount - 1) * crossAxisSpacing)) /
                            crossAxisCount;

                        // Target image proportion (16:10); Expanded in _ImageLayout
                        // will fill remaining space, so this is the allocation target.
                        final imageHeight = cardWidth / 1.6;

                        // Mirror _ImageLayout's rFont calculations.
                        final titleSize = rFont(
                          cardWidth,
                          15,
                          min: 13,
                          max: 17,
                          baseWidth: cardBaseW,
                        );
                        final subtitleSize = rFont(
                          cardWidth,
                          12,
                          min: 11,
                          max: 13,
                          baseWidth: cardBaseW,
                        );
                        // padding(top:10 + bottom:10) + title + gap(3) + subtitle.
                        // ×1.6 + 6px buffer covers Flutter's platform line-height
                        // variance and text-scale-factor > 1 without overflow.
                        final textAreaHeight =
                            20.0 +
                            titleSize * 1.6 +
                            3.0 +
                            subtitleSize * 1.6 +
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

                    // Only 10px below Our Services section
                    const SizedBox(height: 10),

                    // ── Recent Notifications ──────────────────────────
                    const _RecentNotifications(),

                    const SizedBox(height: 100), // bottom nav clearance
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
                      color: _kOrange,
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
            color: isUnread ? const Color(0xFFFFF7F4) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isUnread
                  ? _kOrange.withValues(alpha: 0.2)
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
                      ? _kOrange.withValues(alpha: 0.12)
                      : const Color(0xFFF1F5F9),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.notifications_outlined,
                  size: 17,
                  color: isUnread ? _kOrange : _kGray,
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
                        fontWeight: isUnread
                            ? FontWeight.w600
                            : FontWeight.w500,
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
                style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
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
