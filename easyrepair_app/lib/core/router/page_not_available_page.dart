import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../l10n/l10n_extensions.dart';
import '../theme/app_semantic_colors.dart';

/// Global fallback for an unknown/invalid route (GoRouter's `errorBuilder`)
/// — never exposes the attempted path or any exception text.
///
/// "Go to Home" always targets `/splash`, not a specific role's home route
/// directly: the router's own top-level `redirect` (see app_router.dart)
/// already dispatches `/splash` to the correct destination for the current
/// session — logged-out → auth, suspended Worker → the suspended screen,
/// Worker → Worker Home, Client → Client Home — so this screen never needs
/// its own copy of that role/suspension logic, and can never be used to
/// route around the suspension gate.
class PageNotAvailablePage extends StatelessWidget {
  const PageNotAvailablePage({super.key});

  void _goHome(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/splash');
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;
    return PopScope(
      // Never let Android back reveal the invalid route again — always land
      // on a real, redirect-resolved screen instead.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _goHome(context);
      },
      child: Scaffold(
        backgroundColor: c.background,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: c.softTeal,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.search_off_rounded,
                      size: 34,
                      color: c.primary,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    context.l10n.pageNotAvailableTitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: c.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.l10n.pageNotAvailableBody,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: c.textSecondary),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => _goHome(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: c.primary,
                      foregroundColor: c.onPrimary,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 28,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      context.l10n.commonGoHome,
                      style: const TextStyle(fontWeight: FontWeight.w700),
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
