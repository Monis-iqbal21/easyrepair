import 'package:flutter/material.dart';

import '../../domain/entities/booking_entity.dart';
import '../providers/booking_providers.dart';
import '../../../../core/l10n/l10n_extensions.dart';
import '../../../../core/theme/app_semantic_colors.dart';

class BookingFilterSheet extends StatefulWidget {
  final BookingFilter currentFilter;
  final ValueChanged<BookingFilter> onApply;
  final VoidCallback onReset;

  const BookingFilterSheet({
    super.key,
    required this.currentFilter,
    required this.onApply,
    required this.onReset,
  });

  @override
  State<BookingFilterSheet> createState() => _BookingFilterSheetState();
}

class _BookingFilterSheetState extends State<BookingFilterSheet> {
  late BookingUrgency? _urgency;
  late SortOrder _sortOrder;
  late bool? _hasWorker;

  @override
  void initState() {
    super.initState();
    _urgency = widget.currentFilter.urgency;
    _sortOrder = widget.currentFilter.sortOrder;
    _hasWorker = widget.currentFilter.hasWorker;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 20),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: c.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Text(
                  context.l10n.filterTitle,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: c.textPrimary,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _urgency = null;
                      _sortOrder = SortOrder.newest;
                      _hasWorker = null;
                    });
                    widget.onReset();
                    Navigator.pop(context);
                  },
                  child: Text(
                    context.l10n.filterReset,
                    style: TextStyle(
                      fontSize: 13,
                      color: c.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Urgency
          _SectionLabel(label: context.l10n.bookingUrgency),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _ChipGroup<BookingUrgency?>(
              value: _urgency,
              options: const [
                null,
                BookingUrgency.urgent,
                BookingUrgency.normal,
              ],
              labelOf: (v) => v == null
                  ? context.l10n.filterAll
                  : v == BookingUrgency.urgent
                  ? context.l10n.filterUrgentOption
                  : context.l10n.filterNormalOption,
              onSelected: (v) => setState(() => _urgency = v),
            ),
          ),

          const SizedBox(height: 20),

          // Sort
          _SectionLabel(label: context.l10n.filterSortByDate),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _ChipGroup<SortOrder>(
              value: _sortOrder,
              options: const [SortOrder.newest, SortOrder.oldest],
              labelOf: (v) => v == SortOrder.newest
                  ? context.l10n.filterNewestFirst
                  : context.l10n.filterOldestFirst,
              onSelected: (v) => setState(() => _sortOrder = v),
            ),
          ),

          const SizedBox(height: 20),

          // Worker assignment
          _SectionLabel(label: context.l10n.trackWorkerLabel),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _ChipGroup<bool?>(
              value: _hasWorker,
              options: const [null, true, false],
              labelOf: (v) => v == null
                  ? context.l10n.filterAll
                  : v
                  ? context.l10n.bookingStatusAssigned
                  : context.l10n.cardNoWorkerYet,
              onSelected: (v) => setState(() => _hasWorker = v),
            ),
          ),

          const SizedBox(height: 28),

          // Apply button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () {
                  widget.onApply(
                    widget.currentFilter.copyWith(
                      urgency: _urgency,
                      sortOrder: _sortOrder,
                      hasWorker: _hasWorker,
                    ),
                  );
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: c.primary,
                  foregroundColor: c.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                  minimumSize: Size.zero,
                ),
                child: Text(
                  context.l10n.filterApply,
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: c.textSecondary,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _ChipGroup<T> extends StatelessWidget {
  final T value;
  final List<T> options;
  final String Function(T) labelOf;
  final ValueChanged<T> onSelected;

  const _ChipGroup({
    required this.value,
    required this.options,
    required this.labelOf,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options
          .map(
            (o) => _Chip(
              label: labelOf(o),
              isSelected: value == o,
              onTap: () => onSelected(o),
            ),
          )
          .toList(),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _Chip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? c.primary : c.background,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? c.primary : c.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: isSelected ? c.onPrimary : c.textSecondary,
          ),
        ),
      ),
    );
  }
}
