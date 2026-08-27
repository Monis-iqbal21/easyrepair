import 'package:flutter/material.dart';

import '../../../../../core/l10n/l10n_extensions.dart';
import '../../../../../core/theme/app_semantic_colors.dart';
import '../../../domain/entities/booking_entity.dart';
import 'booking_detail_primitives.dart';

/// Where the job is — as text.
///
/// Deliberately map-free: live tracking is the Track Ustaad page's job, and
/// an embedded map here duplicated it while costing a Google Maps surface on
/// every booking the client opened.
class BookingLocationSection extends StatelessWidget {
  final BookingEntity booking;

  const BookingLocationSection({super.key, required this.booking});

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;
    final l10n = context.l10n;
    final address = booking.address?.trim();
    final hasAddress = address != null && address.isNotEmpty;
    final city = booking.city.trim();

    return BookingDetailCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BookingSectionHeading(
            label: l10n.postJobServiceAddress,
            icon: Icons.location_on_outlined,
          ),
          const SizedBox(height: 12),
          Text(
            hasAddress ? address : l10n.bookingNoAddressProvided,
            style: TextStyle(
              fontSize: 14,
              height: 1.45,
              fontWeight: hasAddress ? FontWeight.w600 : FontWeight.w400,
              color: hasAddress ? colors.textPrimary : colors.textSecondary,
            ),
          ),
          if (city.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              city,
              style: TextStyle(fontSize: 13, color: colors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}
