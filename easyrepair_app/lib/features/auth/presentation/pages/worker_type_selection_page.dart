import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../widgets/auth_header.dart';
import '../widgets/selection_card.dart';
import '../../../../core/l10n/l10n_extensions.dart';

/// Shown after choosing "Ustaad" on the role-selection page — decides
/// between new-Ustaad registration and existing-Ustaad login.
class WorkerTypeSelectionPage extends StatefulWidget {
  const WorkerTypeSelectionPage({super.key});

  @override
  State<WorkerTypeSelectionPage> createState() =>
      _WorkerTypeSelectionPageState();
}

class _WorkerTypeSelectionPageState extends State<WorkerTypeSelectionPage> {
  String? _selected;

  Future<void> _select(String key, String route) async {
    if (_selected != null) return;
    setState(() => _selected = key);
    await Future<void>.delayed(const Duration(milliseconds: 140));
    if (!mounted) return;
    // push, not go - see RoleSelectionPage._select. Each auth step must stay
    // on the stack so Back returns to the exact preceding screen.
    context.push(route);
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
                        AuthHeader(
                          title: context.l10n.authWorkerTypeQuestion,
                          subtitle: '',
                          isSmall: isSmall,
                          showBackButton: true,
                        ),
                        SizedBox(height: isSmall ? 20 : 32),
                        SelectionCard(
                          icon: Icons.person_add_alt_1_rounded,
                          title: context.l10n.authWorkerTypeNewTitle,
                          subtitle: context.l10n.authWorkerTypeNewSubtitle,
                          isSelected: _selected == 'new',
                          onTap: () =>
                              _select('new', '/auth/worker/register'),
                        ),
                        const SizedBox(height: 16),
                        SelectionCard(
                          icon: Icons.login_rounded,
                          title: context.l10n.authWorkerTypeExistingTitle,
                          subtitle: context.l10n.authWorkerTypeExistingSubtitle,
                          isSelected: _selected == 'existing',
                          onTap: () =>
                              _select('existing', '/auth/worker/login'),
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
