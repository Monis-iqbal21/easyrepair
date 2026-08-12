import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/auth/presentation/providers/auth_providers.dart';
import '../../../core/errors/failure_messages.dart';
import '../../../core/l10n/l10n_extensions.dart';

class SplashPage extends ConsumerWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final logoWidth = (MediaQuery.sizeOf(context).width * 0.44).clamp(112.0, 208.0);

    // A transient failure (no internet, timeout, backend 5xx) on the very
    // first session check, with nothing previously confirmed to fall back
    // on — see AuthStateNotifier and app_router.dart's redirect. This never
    // means the session was destroyed; it just couldn't be confirmed yet,
    // so offer a retry instead of guessing either way.
    final showRetry = authState.hasError && !authState.hasValue;

    return Scaffold(
      backgroundColor: const Color(0xFFFFFEFB),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/images/logo-green.png',
                width: logoWidth,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 48),
              if (showRetry) ...[
                Text(
                  failureMessage(context.l10n, authState.error),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => ref.invalidate(authStateProvider),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDB6234),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                  ),
                  child: Text(context.l10n.commonRetry),
                ),
              ] else
                const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFDB6234)),
                    strokeWidth: 2.5,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
