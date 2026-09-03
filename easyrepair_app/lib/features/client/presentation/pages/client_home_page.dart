import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/l10n_extensions.dart';
import '../../../../core/theme/app_semantic_colors.dart';
import '../../../../core/theme/theme_mode_provider.dart';
import '../../../../core/widgets/handygo_brand_lockup.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../notifications/presentation/providers/notification_providers.dart';
import '../../../categories/domain/entities/service_category_entity.dart';
import '../../../categories/presentation/providers/categories_providers.dart';
import '../widgets/service_card.dart';
import '../widgets/service_data.dart';

final currentClientAreaProvider = FutureProvider<String?>((ref) async {
  try {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.low,
        timeLimit: Duration(seconds: 6),
      ),
    );
    final marks = await placemarkFromCoordinates(
      position.latitude,
      position.longitude,
    );
    if (marks.isEmpty) return null;
    final mark = marks.first;
    final parts = <String>{
      if (mark.subLocality?.isNotEmpty == true) mark.subLocality!,
      if (mark.locality?.isNotEmpty == true) mark.locality!,
    };
    return parts.isEmpty ? null : parts.join(', ');
  } catch (_) {
    return null;
  }
});

class ClientHomePage extends ConsumerWidget {
  const ClientHomePage({super.key});

  List<_Service> _services(
    BuildContext context,
    List<ServiceCategoryEntity> categories,
  ) => [
    _Service(context.l10n.serviceAcTechnician, 'AC Technician', '❄️'),
    _Service(context.l10n.serviceElectrician, 'Electrician', '⚡'),
    _Service(context.l10n.servicePlumber, 'Plumber', '🔧'),
    _Service(context.l10n.serviceCarpenter, 'Carpenter', '🪚'),
    _Service(context.l10n.serviceAppliancesRepair, 'Appliances Repair', '🧺'),
    _Service(context.l10n.serviceDeepCleaning, 'Cleaner', '🧹'),
    _Service(context.l10n.servicePestControl, 'Pest Control', '🐛'),
    _Service(context.l10n.servicePainter, 'Painter', '🎨'),
    _Service(context.l10n.serviceGardening, 'Gardener', '🌿'),
    _Service(context.l10n.serviceCarWash, 'Car Wash', '🚗'),
  ].map((service) => service.withCategory(categories)).toList();

  void _open(
    BuildContext context,
    _Service service, {
    bool urgentEntry = false,
  }) => context.push(
    Uri(
      path: '/client/post-job',
      queryParameters: {
        'service': service.category?.name ?? service.backendName,
        if (service.category?.id.isNotEmpty == true)
          'categoryId': service.category!.id,
        if (urgentEntry) 'urgentEntry': '1',
      },
    ).toString(),
  );

  Future<void> _urgentPicker(BuildContext context, List<_Service> services) {
    final colors = context.semanticColors;
    final available = services
        .where(
          (item) => kLaunchActiveServiceCategories.contains(item.backendName),
        )
        .toList();
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(width: 40, height: 4, color: colors.border),
              ),
              const SizedBox(height: 18),
              Text(
                context.l10n.clientHomeBookUrgently,
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                context.l10n.clientHomeChooseServiceHelp,
                style: TextStyle(color: colors.textSecondary),
              ),
              const SizedBox(height: 18),
              Flexible(
                child: GridView.builder(
                  shrinkWrap: true,
                  itemCount: available.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    childAspectRatio: 1.35,
                  ),
                  itemBuilder: (_, index) {
                    final item = available[index];
                    return ServiceCard(
                      title: item.title,
                      emoji: item.emoji,
                      backgroundColor: colors.surfaceSubtle,
                      emojiBackgroundColor: colors.softTeal,
                      imagePath: imagePathForCategory(item.backendName),
                      useImageStyle: true,
                      onTap: () {
                        Navigator.of(sheetContext).pop();
                        _open(context, item, urgentEntry: true);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.semanticColors;
    final user = ref.watch(authStateProvider).valueOrNull;
    final rawName = user?.firstName.trim();
    final firstName = rawName == null || rawName.isEmpty
        ? context.l10n.clientHomeGuest
        : rawName;
    final services = _services(
      context,
      ref.watch(allCategoriesProvider).valueOrNull ?? const [],
    );
    final width = MediaQuery.sizeOf(context).width;
    final side = width <= 340 ? 14.0 : 18.0;

    return ColoredBox(
      color: colors.background,
      child: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(side, 14, side, 0),
                  sliver: SliverToBoxAdapter(
                    child: _Header(
                      firstName: firstName,
                      area: ref.watch(currentClientAreaProvider),
                      unread:
                          ref
                              .watch(unreadNotificationCountProvider)
                              .valueOrNull ??
                          0,
                      isDark: Theme.of(context).brightness == Brightness.dark,
                      onTheme: () =>
                          ref.read(themeModeProvider.notifier).toggle(),
                      onNotifications: () => context.push('/notifications'),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(side, 18, side, 0),
                  sliver: SliverToBoxAdapter(
                    child: _UrgentBanner(
                      onTap: () => _urgentPicker(context, services),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(side, 22, side, 12),
                  sliver: SliverToBoxAdapter(
                    child: Text(
                      context.l10n.clientHomeWhatNeedsDoing,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: EdgeInsets.symmetric(horizontal: side),
                  sliver: SliverGrid.builder(
                    itemCount: services.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: width <= 340 ? 14 : 18,
                      crossAxisSpacing: width <= 340 ? 10 : 14,
                      childAspectRatio: width <= 340 ? 1.3 : 1.42,
                    ),
                    itemBuilder: (_, index) {
                      final item = services[index];
                      return ServiceCard(
                        title: item.title,
                        emoji: item.emoji,
                        backgroundColor: colors.surfaceSubtle,
                        emojiBackgroundColor: colors.softTeal,
                        imagePath: imagePathForCategory(item.backendName),
                        useImageStyle: true,
                        locked: !kLaunchActiveServiceCategories.contains(
                          item.backendName,
                        ),
                        onTap: () => _open(context, item),
                      );
                    },
                  ),
                ),
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(side, 24, side, 96),
                  sliver: const SliverToBoxAdapter(child: _TrustStrip()),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.firstName,
    required this.area,
    required this.unread,
    required this.isDark,
    required this.onTheme,
    required this.onNotifications,
  });
  final String firstName;
  final AsyncValue<String?> area;
  final int unread;
  final bool isDark;
  final VoidCallback onTheme;
  final VoidCallback onNotifications;

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;
    final location = area.when(
      data: (value) => value ?? context.l10n.clientHomeYourArea,
      loading: () => context.l10n.clientHomeLocating,
      error: (_, _) => context.l10n.clientHomeYourArea,
    );
    return Row(
      children: [
        const HandyGoBrandMark(size: 31, semanticLabel: 'HandyGo'),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n.clientHomeHello(firstName),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colors.primary,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Icon(
                    Icons.location_on_outlined,
                    size: 13,
                    color: colors.textSecondary,
                  ),
                  const SizedBox(width: 3),
                  Expanded(
                    child: Text(
                      location,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: 11.5,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        _Action(
          icon: isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
          onTap: onTheme,
        ),
        const SizedBox(width: 8),
        Stack(
          clipBehavior: Clip.none,
          children: [
            _Action(icon: Icons.notifications_outlined, onTap: onNotifications),
            if (unread > 0)
              PositionedDirectional(
                top: -3,
                end: -3,
                child: Container(
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: colors.error,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    unread > 9 ? '9+' : '$unread',
                    style: TextStyle(
                      color: colors.surface,
                      fontSize: 8,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;
    return Material(
      color: colors.surfaceSubtle,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox.square(
          dimension: 44,
          child: Icon(icon, color: colors.textPrimary, size: 20),
        ),
      ),
    );
  }
}

class _UrgentBanner extends StatelessWidget {
  const _UrgentBanner({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;
    return Material(
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colors.primary),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 19,
                backgroundColor: colors.primary,
                foregroundColor: colors.onPrimary,
                child: const Icon(Icons.bolt_rounded),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 7,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          context.l10n.clientHomeUrgentTitle,
                          style: TextStyle(
                            color: colors.primary,
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: colors.primary,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '24/7',
                            style: TextStyle(
                              color: colors.onPrimary,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      context.l10n.clientHomeUrgentPromise,
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: 11.5,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              CircleAvatar(
                radius: 18,
                backgroundColor: colors.primary,
                foregroundColor: colors.onPrimary,
                child: const Icon(Icons.arrow_forward_rounded, size: 18),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrustStrip extends StatelessWidget {
  const _TrustStrip();
  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colors.softTeal,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          Icon(Icons.verified_user_outlined, color: colors.primary, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              context.l10n.clientHomeTrustMessage,
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Service {
  const _Service(this.title, this.backendName, this.emoji, {this.category});
  final String title;
  final String backendName;
  final String emoji;
  final ServiceCategoryEntity? category;

  // The static Home catalog has no IDs. Bind it to the API once at this
  // boundary, then carry the canonical ID independently of localized copy.
  _Service withCategory(List<ServiceCategoryEntity> categories) {
    for (final category in categories) {
      if (category.name.trim().toLowerCase() == backendName.toLowerCase()) {
        return _Service(title, backendName, emoji, category: category);
      }
    }
    return this;
  }
}
