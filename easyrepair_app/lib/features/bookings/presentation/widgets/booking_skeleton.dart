import 'package:flutter/material.dart';

/// Simple shimmer-style skeleton for booking cards.
class BookingSkeleton extends StatefulWidget {
  const BookingSkeleton({super.key});

  @override
  State<BookingSkeleton> createState() => _BookingSkeletonState();
}

class _BookingSkeletonState extends State<BookingSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.35, end: 0.9).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) {
        return Column(
          children: List.generate(
            3,
            (_) => _SkeletonCard(opacity: _anim.value),
          ),
        );
      },
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  final double opacity;
  const _SkeletonCard({required this.opacity});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Box(width: 46, height: 46, radius: 14),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Box(width: 120, height: 14, radius: 6),
                      const SizedBox(height: 6),
                      _Box(width: 80, height: 10, radius: 4),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _Box(width: 60, height: 20, radius: 10),
                    const SizedBox(height: 4),
                    _Box(width: 50, height: 18, radius: 10),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            _Box(width: double.infinity, height: 10, radius: 4),
            const SizedBox(height: 5),
            _Box(width: 160, height: 10, radius: 4),
            const SizedBox(height: 12),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            const SizedBox(height: 12),
            Row(
              children: [
                _Box(width: 34, height: 34, radius: 17),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Box(width: 90, height: 11, radius: 4),
                    const SizedBox(height: 4),
                    _Box(width: 60, height: 9, radius: 4),
                  ],
                ),
                const Spacer(),
                _Box(width: 50, height: 18, radius: 6),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Box extends StatelessWidget {
  final double width;
  final double height;
  final double radius;

  const _Box({
    required this.width,
    required this.height,
    required this.radius,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}
