import 'package:flutter/material.dart';

/// Shows an animated welcome card anchored to the bottom of the screen.
/// Auto-dismisses after ~2 seconds with a slide+fade animation.
void showWelcomeToast(BuildContext context, String name) {
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _WelcomeToast(
      name: name,
      onDismiss: () {
        if (entry.mounted) entry.remove();
      },
    ),
  );
  Overlay.of(context, rootOverlay: true).insert(entry);
  Future.delayed(const Duration(milliseconds: 2400), () {
    if (entry.mounted) entry.remove();
  });
}

class _WelcomeToast extends StatefulWidget {
  final String name;
  final VoidCallback onDismiss;

  const _WelcomeToast({required this.name, required this.onDismiss});

  @override
  State<_WelcomeToast> createState() => _WelcomeToastState();
}

class _WelcomeToastState extends State<_WelcomeToast>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<Offset> _slide;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.6),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);

    _ctrl.forward();

    // Begin reverse 400 ms before the entry is removed
    Future.delayed(const Duration(milliseconds: 1700), () {
      if (mounted) _ctrl.reverse();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return Positioned(
      bottom: bottom + 28,
      left: 20,
      right: 20,
      child: SlideTransition(
        position: _slide,
        child: FadeTransition(
          opacity: _fade,
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x1A000000),
                    blurRadius: 24,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFDE7356),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: const Icon(
                      Icons.waving_hand_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Welcome, ${widget.name}!',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1A1A1A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Your account is ready to go.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
