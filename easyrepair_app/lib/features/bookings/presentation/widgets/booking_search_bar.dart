import 'dart:async';

import 'package:flutter/material.dart';
import '../../../../core/l10n/l10n_extensions.dart';
import '../../../../core/theme/app_semantic_colors.dart';

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
    final c = context.semanticColors;
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 46,
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: c.border),
              boxShadow: [
                BoxShadow(
                  color: c.scrim.withValues(alpha: 0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: _controller,
              onChanged: _onTextChanged,
              style: TextStyle(fontSize: 13.5, color: c.textPrimary),
              decoration: InputDecoration(
                hintText: context.l10n.searchBookingsHint,
                hintStyle: TextStyle(fontSize: 13.5, color: c.textSecondary),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  size: 18,
                  color: c.textSecondary,
                ),
                suffixIcon: _controller.text.isNotEmpty
                    ? GestureDetector(
                        onTap: () {
                          _controller.clear();
                          widget.onChanged('');
                        },
                        child: Icon(
                          Icons.close_rounded,
                          size: 16,
                          color: c.textSecondary,
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
    final c = context.semanticColors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: hasActiveFilters ? c.primary : c.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: hasActiveFilters ? c.primary : c.border),
          boxShadow: [
            BoxShadow(
              color: c.scrim.withValues(alpha: 0.04),
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
                color: hasActiveFilters ? c.onPrimary : c.textSecondary,
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
                    color: c.warning,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: hasActiveFilters ? c.primary : c.surface,
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
