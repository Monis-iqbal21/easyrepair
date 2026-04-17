import 'package:flutter/material.dart';

import '../../domain/entities/booking_entity.dart';
import '../providers/booking_providers.dart';

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
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                const Text(
                  'Filter Bookings',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1A1A),
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
                  child: const Text(
                    'Reset',
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFFDE7356),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Urgency
          _SectionLabel(label: 'Urgency'),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _ChipGroup<BookingUrgency?>(
              value: _urgency,
              options: const [null, BookingUrgency.urgent, BookingUrgency.normal],
              labelOf: (v) => v == null
                  ? 'All'
                  : v == BookingUrgency.urgent
                      ? '⚡ Urgent'
                      : '🗓 Normal',
              onSelected: (v) => setState(() => _urgency = v),
            ),
          ),

          const SizedBox(height: 20),

          // Sort
          _SectionLabel(label: 'Sort by date'),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _ChipGroup<SortOrder>(
              value: _sortOrder,
              options: const [SortOrder.newest, SortOrder.oldest],
              labelOf: (v) =>
                  v == SortOrder.newest ? 'Newest first' : 'Oldest first',
              onSelected: (v) => setState(() => _sortOrder = v),
            ),
          ),

          const SizedBox(height: 20),

          // Worker assignment
          _SectionLabel(label: 'Worker'),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _ChipGroup<bool?>(
              value: _hasWorker,
              options: const [null, true, false],
              labelOf: (v) => v == null
                  ? 'All'
                  : v
                      ? 'Assigned'
                      : 'No worker yet',
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
                  backgroundColor: const Color(0xFFDE7356),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                  minimumSize: Size.zero,
                ),
                child: const Text(
                  'Apply Filters',
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Color(0xFF6B7280),
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
          .map((o) => _Chip(
                label: labelOf(o),
                isSelected: value == o,
                onTap: () => onSelected(o),
              ))
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
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFDE7356) : const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? const Color(0xFFDE7356)
                : const Color(0xFFE2E8F0),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: isSelected ? Colors.white : const Color(0xFF6B7280),
          ),
        ),
      ),
    );
  }
}
