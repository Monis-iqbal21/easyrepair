import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../notifications/domain/entities/notification_entity.dart';
import '../../../notifications/presentation/providers/notification_providers.dart';
import '../../../../core/presentation/responsive_utils.dart';
import '../widgets/client_bottom_nav_bar.dart';
import '../widgets/service_card.dart';

const _kGreen = Color(0xFFDB6234);
const _kDark = Color(0xFF1A1A1A);
const _kGray = Color(0xFF6B7280);

// Fetches current area label (subLocality → locality → "Your Area").
final _currentAreaProvider = FutureProvider<String>((ref) async {
  try {
    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      return 'Your Area';
    }
    final pos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.low,
        timeLimit: Duration(seconds: 6),
      ),
    );
    final marks = await placemarkFromCoordinates(pos.latitude, pos.longitude);
    if (marks.isEmpty) return 'Your Area';
    final m = marks.first;
    return m.subLocality?.isNotEmpty == true
        ? m.subLocality!
        : m.locality?.isNotEmpty == true
            ? m.locality!
            : 'Your Area';
  } catch (_) {
    return 'Your Area';
  }
});

class ClientHomePage extends ConsumerStatefulWidget {
  const ClientHomePage({super.key});

  @override
  ConsumerState<ClientHomePage> createState() => _ClientHomePageState();
}

class _ClientHomePageState extends ConsumerState<ClientHomePage> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Fixed homepage sections — display-layer only, no backend/worker impact.
  static const _kSections = [
    _SectionData(
      heading: 'Repairs',
      items: [
        _HomeServiceItem(
          displayTitle: 'AC Technician',
          backendName: 'AC Technician',
          emoji: '❄️',
          bg: Color(0xFFE8F4F8),
          emojiBg: Color(0xFFB2DFF0),
          imagePath: 'assets/images/ac.jpg',
        ),
        _HomeServiceItem(
          displayTitle: 'Electrician',
          backendName: 'Electrician',
          emoji: '⚡',
          bg: Color(0xFFFFF8E1),
          emojiBg: Color(0xFFFFECB3),
          imagePath: 'assets/images/electrician.jpg',
        ),
        _HomeServiceItem(
          displayTitle: 'Plumber',
          backendName: 'Plumber',
          emoji: '🔧',
          bg: Color(0xFFE8F5E9),
          emojiBg: Color(0xFFC8E6C9),
          imagePath: 'assets/images/plumber.jpg',
        ),
        _HomeServiceItem(
          displayTitle: 'Carpenter',
          backendName: 'Carpenter',
          emoji: '🪚',
          bg: Color(0xFFEFEBE9),
          emojiBg: Color(0xFFD7CCC8),
          imagePath: 'assets/images/carpenter.jpg',
        ),
      ],
    ),
    _SectionData(
      heading: 'Cleaning',
      items: [
        _HomeServiceItem(
          displayTitle: 'Deep Cleaning',
          backendName: 'Cleaner',
          emoji: '🧹',
          bg: Color(0xFFFFF3E0),
          emojiBg: Color(0xFFFFE0B2),
          imagePath: 'assets/images/deepcleaning.png',
        ),
        _HomeServiceItem(
          displayTitle: 'Pest Control',
          backendName: 'Pest Control',
          emoji: '🐛',
          bg: Color(0xFFE8F5E9),
          emojiBg: Color(0xFFC8E6C9),
          imagePath: 'assets/images/pest.png',
        ),
      ],
    ),
    _SectionData(
      heading: 'Painting',
      items: [
        _HomeServiceItem(
          displayTitle: 'Painter',
          backendName: 'Painter',
          emoji: '🎨',
          bg: Color(0xFFFCE4EC),
          emojiBg: Color(0xFFF8BBD0),
          imagePath: 'assets/images/painting.jpg',
        ),
      ],
    ),
    _SectionData(
      heading: 'Outdoor & Vehicle',
      items: [
        _HomeServiceItem(
          displayTitle: 'Gardening',
          backendName: 'Gardener',
          emoji: '🌿',
          bg: Color(0xFFE8F5E9),
          emojiBg: Color(0xFFA5D6A7),
          imagePath: 'assets/images/gardening.jpg',
        ),
        _HomeServiceItem(
          displayTitle: 'Car Wash',
          backendName: 'Car Wash',
          emoji: '🚗',
          bg: Color(0xFFE3F2FD),
          emojiBg: Color(0xFFBBDEFB),
          imagePath: 'assets/images/carwash.png',
        ),
      ],
    ),
  ];

  Widget _buildServiceSections(BuildContext context) {
    void onTap(_HomeServiceItem item) {
      context.push(
        '/client/post-job?service=${Uri.encodeComponent(item.backendName)}',
      );
    }

    final q = _searchQuery.toLowerCase();

    if (q.isNotEmpty) {
      final matched = [
        for (final sec in _kSections)
          for (final item in sec.items)
            if (item.displayTitle.toLowerCase().contains(q) ||
                item.backendName.toLowerCase().contains(q))
              item,
      ];

      if (matched.isEmpty) {
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 32),
          child: Center(
            child: Text(
              'No services found',
              style: TextStyle(fontSize: 14, color: Color(0xFF94A3B8)),
            ),
          ),
        );
      }

      return _ServiceSection(
        heading: 'Search Results',
        items: matched,
        onItemTap: onTap,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final sec in _kSections)
          _ServiceSection(
            heading: sec.heading,
            items: sec.items,
            onItemTap: onTap,
          ),
        const _MoversPackersCard(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final user = authState.valueOrNull;
    final firstName = user?.firstName ?? 'there';
    final screenWidth = MediaQuery.sizeOf(context).width;

    return Scaffold(
      backgroundColor: const Color(0xFFFFFEFB),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // ── Header: logo + Handygo | location pill | notification ─────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  // Logo icon
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.asset(
                      'assets/images/logo-green.png',
                      height: 30,
                      width: 30,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: _kGreen.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.home_repair_service_rounded,
                          color: _kGreen,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 7),
                  Text(
                    'Handygo',
                    style: TextStyle(
                      fontSize: rFont(screenWidth, 19, min: 16, max: 22),
                      fontWeight: FontWeight.w800,
                      color: _kGreen,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const Spacer(),
                  // Dynamic location pill
                  Consumer(
                    builder: (_, cRef, _) {
                      final area =
                          cRef.watch(_currentAreaProvider).valueOrNull ??
                          'Your Area';
                      return Container(
                        constraints: BoxConstraints(
                          maxWidth: screenWidth * 0.32,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF8F5),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: const Color(0xFFE2E8F0),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.location_on_rounded,
                              size: 12,
                              color: _kGreen,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                area,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: _kDark,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 10),
                  // Notification bell with unread badge
                  GestureDetector(
                    onTap: () => context.push('/notifications'),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 38,
                          height: 38,
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
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Compact greeting + search pill ────────────────────
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(50),
                        border: Border.all(
                          color: const Color(0xFFE2E8F0),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          if (_searchQuery.isEmpty) ...[
                            Text(
                              'Hi $firstName 👋',
                              style: TextStyle(
                                fontSize: rFont(screenWidth, 13, min: 11, max: 14),
                                fontWeight: FontWeight.w600,
                                color: _kDark,
                              ),
                            ),
                            Container(
                              margin: const EdgeInsets.symmetric(horizontal: 8),
                              width: 1,
                              height: 14,
                              color: const Color(0xFFE2E8F0),
                            ),
                          ],
                          const Icon(
                            Icons.search_rounded,
                            color: _kGreen,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              onChanged: (v) =>
                                  setState(() => _searchQuery = v.trim()),
                              style: TextStyle(
                                fontSize: rFont(screenWidth, 13, min: 11, max: 14),
                                color: _kDark,
                              ),
                              decoration: InputDecoration(
                                hintText: _searchQuery.isEmpty
                                    ? 'Search services...'
                                    : null,
                                hintStyle: TextStyle(
                                  fontSize: rFont(screenWidth, 12, min: 11, max: 13),
                                  color: const Color(0xFF94A3B8),
                                ),
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ),
                          if (_searchQuery.isNotEmpty)
                            GestureDetector(
                              onTap: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                              child: const Icon(
                                Icons.close_rounded,
                                size: 18,
                                color: _kGray,
                              ),
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ── Seasonal AC banner ────────────────────────────────────
                    _SeasonalBanner(
                      onBookAC: () => context.push(
                        '/client/post-job?service='
                        '${Uri.encodeComponent('AC Technician')}',
                      ),
                    ),

                    const SizedBox(height: 12),

                    // ── Urgent help card ──────────────────────────────────────
                    _UrgentHelpCard(
                      onBookUrgently: () => context.push('/client/post-job'),
                    ),

                    const SizedBox(height: 24),

                    // ── Service sections ──────────────────────────────────
                    _buildServiceSections(context),

                    // ── Recent Notifications ──────────────────────────────
                    const _RecentNotifications(),

                    const SizedBox(height: 90),
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

// ── Data models ───────────────────────────────────────────────────────────────

class _HomeServiceItem {
  final String displayTitle;
  final String backendName;
  final String emoji;
  final Color bg;
  final Color emojiBg;
  final String? imagePath;

  const _HomeServiceItem({
    required this.displayTitle,
    required this.backendName,
    required this.emoji,
    required this.bg,
    required this.emojiBg,
    this.imagePath,
  });
}

class _SectionData {
  final String heading;
  final List<_HomeServiceItem> items;
  const _SectionData({required this.heading, required this.items});
}

// ── Movers & Packers coming soon card ────────────────────────────────────────

class _MoversPackersCard extends StatelessWidget {
  const _MoversPackersCard();

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Movers & Packers',
          style: TextStyle(
            fontSize: rFont(screenWidth, 16, min: 14, max: 18),
            fontWeight: FontWeight.w700,
            color: _kDark,
          ),
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.asset(
            'assets/images/banner.png',
            width: double.infinity,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

// ── Seasonal AC banner ────────────────────────────────────────────────────────

class _SeasonalBanner extends StatelessWidget {
  final VoidCallback onBookAC;
  const _SeasonalBanner({required this.onBookAC});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 130,
        decoration: BoxDecoration(
          color: const Color(0xFFFFF5EF),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFEDD5C5), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Right side AC image
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              width: 140,
              child: Image.asset(
                'assets/images/ac.jpg',
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  color: const Color(0xFFFFE5D5),
                  child: const Icon(Icons.ac_unit_rounded,
                      size: 48, color: Color(0xFFDB6234)),
                ),
              ),
            ),
            // Fade overlay: cream on left blending into transparent on right
            Positioned.fill(
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFFFFF5EF),
                      Color(0xFFFFF5EF),
                      Color(0x99FFF5EF),
                      Colors.transparent,
                    ],
                    stops: [0.0, 0.45, 0.65, 1.0],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                ),
              ),
            ),
            // Left text content
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              right: 80,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Beat the Karachi Heat ☀️',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1A1A1A),
                            height: 1.2,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Get your AC serviced\nbefore it gets worse.',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF6B7280),
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                    GestureDetector(
                      onTap: onBookAC,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDB6234),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Book AC Technician',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Urgent help card ──────────────────────────────────────────────────────────

class _UrgentHelpCard extends StatelessWidget {
  final VoidCallback onBookUrgently;
  const _UrgentHelpCard({required this.onBookUrgently});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Lightning icon circle
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFDB6234).withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.bolt_rounded,
              color: Color(0xFFDB6234),
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          // Text
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Need help now?',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'For urgent issues, book instantly.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Book Urgently button + 24/7 Service caption
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: onBookUrgently,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDB6234),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Book Urgently',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.access_time_filled_rounded,
                    size: 11,
                    color: Color(0xFFDB6234),
                  ),
                  SizedBox(width: 4),
                  Text(
                    '24/7 Service',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFDB6234),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── One categorized service section ──────────────────────────────────────────

class _ServiceSection extends StatelessWidget {
  final String heading;
  final List<_HomeServiceItem> items;
  final void Function(_HomeServiceItem item) onItemTap;

  const _ServiceSection({
    required this.heading,
    required this.items,
    required this.onItemTap,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;

    // cardW derived from screen width minus the outer 20+20 padding that the
    // parent SingleChildScrollView already applies, so heading and cards share
    // the same left edge automatically.
    const hPad = 20.0; // must match parent SingleChildScrollView padding
    const spacing = 10.0;
    final availableW = screenWidth - hPad * 2;
    final cardW = (availableW - spacing) / 2.28;
    final imageH = cardW * 0.55;
    final cardH = imageH + 30; // image + 6px gap + ~18px title + 6px bottom

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          heading,
          style: TextStyle(
            fontSize: rFont(screenWidth, 16, min: 14, max: 18),
            fontWeight: FontWeight.w700,
            color: _kDark,
          ),
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerLeft,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: items.map((s) {
                return Padding(
                  padding: const EdgeInsets.only(right: spacing),
                  child: SizedBox(
                    width: cardW,
                    height: cardH,
                    child: ServiceCard(
                      title: s.displayTitle,
                      emoji: s.emoji,
                      backgroundColor: s.bg,
                      emojiBackgroundColor: s.emojiBg,
                      imagePath: s.imagePath,
                      useImageStyle: true,
                      onTap: () => onItemTap(s),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(height: 20),
      ],
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
            color: isUnread ? const Color(0xFFFFF7F4) : const Color(0xFFFAF9F8),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isUnread
                  ? _kGreen.withValues(alpha: 0.45)
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
                      ? _kGreen.withValues(alpha: 0.14)
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
