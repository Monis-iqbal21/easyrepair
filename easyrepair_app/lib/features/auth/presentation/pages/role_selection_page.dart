import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../widgets/auth_primary_button.dart';
import '../widgets/selection_card.dart';

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
    context.go(route);
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
                          'HandyGo par aap kya karna chahte hain?',
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
                          title: 'Mujhe ghar ke kaam ke liye Ustaad chahiye',
                          subtitle:
                              'Verified Ustaad book karein aur apna kaam asaani se karwayein.',
                          isSelected: _selected == 'client',
                          onTap: () => _select('client', '/auth/client'),
                        ),
                        const SizedBox(height: 16),
                        SelectionCard(
                          icon: Icons.handyman_rounded,
                          title:
                              'Main Ustaad hoon aur kaam hasil karna chahta hoon',
                          subtitle:
                              'HandyGo join karein aur apni skill ke mutabiq kaam hasil karein.',
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
