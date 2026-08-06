import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../widgets/auth_primary_button.dart';
import '../widgets/selection_card.dart';
import '../../../../core/l10n/l10n_extensions.dart';

/// New auth entry page — replaces the old direct Login/Register screen.
/// Roman Urdu throughout, per the redesigned onboarding flow.
class RoleSelectionPage extends StatefulWidget {
  const RoleSelectionPage({super.key});

  @override
  State<RoleSelectionPage> createState() => _RoleSelectionPageState();
}

class _RoleSelectionPageState extends State<RoleSelectionPage> {
  String? _selected;

  Future<void> _select(String key, String route) async {
    if (_selected != null) return; // guards a double-tap mid-navigation
    setState(() => _selected = key);
    await Future<void>.delayed(const Duration(milliseconds: 140));
    if (!mounted) return;
    // push, not go: `go` replaces the stack, which leaves the destination
    // with nothing to pop back to - the AppBar arrow does nothing and the
    // Android Back button closes the app from a mid-flow auth screen.
    //
    // `push` returns once the pushed route (and anything it pushed in turn)
    // is popped back off, i.e. exactly when the user returns here — that's
    // the moment to drop the highlight/tap-guard. Without this, this page's
    // State survives underneath the pushed route (push never disposes it),
    // so `_selected` stayed stuck on whichever card was tapped last time and
    // silently swallowed every tap after Back — a temporary UI choice must
    // never outlive the screen it was made for.
    await context.push(route);
    if (mounted) setState(() => _selected = null);
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final isSmall = mq.size.height < 680;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Image.asset(
                              'assets/images/logo-green.png',
                              width: isSmall ? 40 : 52,
                              height: isSmall ? 40 : 52,
                              fit: BoxFit.contain,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Handygo',
                              style: TextStyle(
                                fontSize: isSmall ? 24 : 28,
                                fontWeight: FontWeight.w800,
                                color: kAuthAccent,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: isSmall ? 24 : 40),
                        Text(
                          context.l10n.authRoleQuestion,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: isSmall ? 21 : 24,
                            fontWeight: FontWeight.w800,
                            color: kAuthDark,
                            height: 1.3,
                          ),
                        ),
                        SizedBox(height: isSmall ? 24 : 36),
                        SelectionCard(
                          icon: Icons.home_repair_service_rounded,
                          title: context.l10n.authRoleClientTitle,
                          subtitle: context.l10n.authRoleClientSubtitle,
                          isSelected: _selected == 'client',
                          onTap: () => _select('client', '/auth/client'),
                        ),
                        const SizedBox(height: 16),
                        SelectionCard(
                          icon: Icons.handyman_rounded,
                          title: context.l10n.authRoleWorkerTitle,
                          subtitle: context.l10n.authRoleWorkerSubtitle,
                          isSelected: _selected == 'worker',
                          onTap: () =>
                              _select('worker', '/auth/worker/choice'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
