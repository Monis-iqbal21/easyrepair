import 'package:flutter/material.dart';

import '../widgets/client_bottom_nav_bar.dart';
import '../../../../core/l10n/l10n_extensions.dart';
import '../../../../core/theme/app_semantic_colors.dart';

class ClientJobsPage extends StatelessWidget {
  const ClientJobsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;
    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  context.l10n.clientJobsTitle,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: c.textPrimary,
                  ),
                ),
              ),
            ),
            Expanded(
              child: Center(
                child: Text(
                  context.l10n.clientJobsEmpty,
                  style: TextStyle(color: c.textSecondary, fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
      extendBody: true,
      bottomNavigationBar: const ClientBottomNavBar(currentIndex: 1),
    );
  }
}
