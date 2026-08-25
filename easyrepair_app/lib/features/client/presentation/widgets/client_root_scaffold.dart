import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/l10n_extensions.dart';
import '../../../../core/theme/app_semantic_colors.dart';
import '../../../chat/presentation/providers/chat_providers.dart';
import 'client_bottom_nav_bar.dart';

class ClientRootScaffold extends ConsumerStatefulWidget {
  const ClientRootScaffold({
    super.key,
    required this.currentIndex,
    required this.child,
  });

  final int currentIndex;
  final Widget child;

  @override
  ConsumerState<ClientRootScaffold> createState() => _ClientRootScaffoldState();
}

class _ClientRootScaffoldState extends ConsumerState<ClientRootScaffold> {
  bool _openingSupport = false;

  Future<void> _openSupport() async {
    if (_openingSupport) return;
    setState(() => _openingSupport = true);
    try {
      var conversations = ref.read(chatConversationsProvider).valueOrNull;
      var support = conversations?.where((item) => item.isSupport).firstOrNull;
      if (support == null) {
        await ref.read(chatConversationsProvider.notifier).refresh();
        conversations = ref.read(chatConversationsProvider).valueOrNull;
        support = conversations?.where((item) => item.isSupport).firstOrNull;
      }
      if (!mounted) return;
      if (support == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.clientHomeSupportUnavailable)),
        );
        return;
      }
      context.push('/client/chat/${support.id}');
    } finally {
      if (mounted) setState(() => _openingSupport = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;
    return Scaffold(
      backgroundColor: colors.background,
      body: widget.child,
      floatingActionButton: FloatingActionButton(
        key: const ValueKey('client-support-fab'),
        onPressed: _openingSupport ? null : _openSupport,
        backgroundColor: colors.primary,
        foregroundColor: colors.onPrimary,
        elevation: 4,
        tooltip: context.l10n.settingsSupportTitle,
        child: _openingSupport
            ? SizedBox.square(
                dimension: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: colors.onPrimary,
                ),
              )
            : const Icon(Icons.support_agent_rounded),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: ClientBottomNavBar(currentIndex: widget.currentIndex),
    );
  }
}
