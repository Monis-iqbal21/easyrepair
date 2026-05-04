import 'dart:async';

import 'package:flutter/material.dart';

class BookingSearchBar extends StatefulWidget {
  final String initialValue;
  final ValueChanged<String> onChanged;
  final VoidCallback? onFilterTap;
  final bool hasActiveFilters;

  const BookingSearchBar({
    super.key,
    this.initialValue = '',
    required this.onChanged,
    this.onFilterTap,
    this.hasActiveFilters = false,
  });

  @override
  State<BookingSearchBar> createState() => _BookingSearchBarState();
}

class _BookingSearchBarState extends State<BookingSearchBar> {
  late final TextEditingController _controller;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onTextChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      widget.onChanged(value);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 46,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: _controller,
              onChanged: _onTextChanged,
              style: const TextStyle(
                fontSize: 13.5,
                color: Color(0xFF1A1A1A),
              ),
              decoration: InputDecoration(
                hintText: 'Search bookings, services...',
                hintStyle: const TextStyle(
                  fontSize: 13.5,
                  color: Color(0xFF94A3B8),
                ),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  size: 18,
                  color: Color(0xFF94A3B8),
                ),
                suffixIcon: _controller.text.isNotEmpty
                    ? GestureDetector(
                        onTap: () {
                          _controller.clear();
                          widget.onChanged('');
                        },
                        child: const Icon(
                          Icons.close_rounded,
                          size: 16,
                          color: Color(0xFF94A3B8),
                        ),
                      )
                    : null,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 13),
                isDense: true,
              ),
            ),
          ),
        ),
        if (widget.onFilterTap != null) ...[
          const SizedBox(width: 10),
          _FilterButton(
            onTap: widget.onFilterTap!,
            hasActiveFilters: widget.hasActiveFilters,
          ),
        ],
      ],
    );
  }
}

class _FilterButton extends StatelessWidget {
  final VoidCallback onTap;
  final bool hasActiveFilters;

  const _FilterButton({required this.onTap, required this.hasActiveFilters});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: hasActiveFilters
              ? const Color(0xFF1D9E75)
              : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: hasActiveFilters
                ? const Color(0xFF1D9E75)
                : const Color(0xFFE2E8F0),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Center(
              child: Icon(
                Icons.tune_rounded,
                size: 18,
                color: hasActiveFilters ? Colors.white : const Color(0xFF6B7280),
              ),
            ),
            if (hasActiveFilters)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: hasActiveFilters
                          ? const Color(0xFF1D9E75)
                          : Colors.white,
                      width: 1,
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
