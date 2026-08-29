import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/l10n_extensions.dart';
import '../services/chat_socket_service.dart';
import '../theme/app_semantic_colors.dart';

/// Reusable top banner/slider — listens to the existing chat socket's
/// `app_banner` event and shows a fading toast at the top of the screen.
/// Works globally for both client and worker (mount once via MaterialApp's
/// `builder`). Does not touch or interfere with any chat socket listener.
class AppBannerOverlay extends StatefulWidget {
  final Widget child;
  const AppBannerOverlay({super.key, required this.child});

  @override
  State<AppBannerOverlay> createState() => _AppBannerOverlayState();
}

class _AppBannerOverlayState extends State<AppBannerOverlay>
    with SingleTickerProviderStateMixin {
  StreamSubscription<Map<String, dynamic>>? _sub;
  Timer? _dismissTimer;
  late final AnimationController _controller;
  late final Animation<Offset> _slide;

  Map<String, dynamic>? _current;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _sub = ChatSocketService.instance.onAppBanner.listen(_show);
  }

  void _show(Map<String, dynamic> payload) {
    if (!mounted) return;
    _dismissTimer?.cancel();
    setState(() => _current = payload);
    _controller.forward(from: 0);
    _dismissTimer = Timer(const Duration(seconds: 5), _dismiss);
  }

  void _dismiss() {
    if (!mounted) return;
    _controller.reverse().then((_) {
      if (mounted) setState(() => _current = null);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _dismissTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;
    final payload = _current;
    return Stack(
      children: [
        widget.child,
        if (payload != null)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: SlideTransition(
                position: _slide,
                child: GestureDetector(
                  onTap: _dismiss,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Material(
                      color: c.surface.withValues(alpha: 0),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: c.surface,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: c.scrim.withValues(alpha: 0.15),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: c.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.notifications_active_rounded,
                                size: 18,
                                color: c.primary,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    (payload['title'] as String?) ??
                                        context
                                            .l10n
                                            .notificationsBannerFallbackTitle,
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w700,
                                      color: c.textPrimary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if ((payload['body'] as String?)
                                          ?.isNotEmpty ==
                                      true) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      payload['body'] as String,
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        color: c.textSecondary,
                                        height: 1.3,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
