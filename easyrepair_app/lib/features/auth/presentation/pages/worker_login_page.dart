import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/failure_messages.dart';
import '../providers/auth_providers.dart';
import '../widgets/auth_header.dart';
import '../widgets/auth_primary_button.dart';
import '../widgets/auth_text_field.dart';
import '../../../../core/l10n/l10n_extensions.dart';

/// Existing Ustaad login — registered phone number + password, nothing else.
///
/// There is deliberately no OTP step here. Login goes straight to the existing
/// `/auth/login` endpoint (via `loginNotifierProvider`), which bcrypt-compares
/// the password and issues the normal access/refresh tokens; the router then
/// dispatches the authenticated Ustaad to their home exactly as before.
///
/// OTP has NOT been weakened anywhere else: Ustaad REGISTRATION still verifies
/// the phone by SMS (`/auth/worker/otp-register`), password reset still sends a
/// code, and Client authentication is untouched. What was removed is the
/// second, password-free way of logging an existing Ustaad in.
class WorkerLoginPage extends ConsumerStatefulWidget {
  const WorkerLoginPage({super.key});

  @override
  ConsumerState<WorkerLoginPage> createState() => _WorkerLoginPageState();
}

class _WorkerLoginPageState extends ConsumerState<WorkerLoginPage> {
  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  String? _validatePhone(String? value) {
    if (value == null || value.isEmpty) {
      return context.l10n.authValidationPhoneRequired;
    }
    if (!RegExp(r'^(\+92|0092|92|0)?[3][0-9]{9}$').hasMatch(value.trim())) {
      return context.l10n.authValidationPhoneInvalid;
    }
    return null;
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _login() async {
    final phoneError = _validatePhone(_phoneCtrl.text);
    if (phoneError != null) {
      _showError(phoneError);
      return;
    }
    if (_passwordCtrl.text.isEmpty) {
      _showError(context.l10n.authValidationPasswordRequired);
      return;
    }
    // The server is the only authority here: it verifies the password, the
    // role, and the account's active state before any token is issued.
    await ref
        .read(loginNotifierProvider.notifier)
        .login(_phoneCtrl.text.trim(), _passwordCtrl.text);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(loginNotifierProvider, (_, state) {
      if (state is AsyncError) {
        _showError(
          failureMessage(
            context.l10n,
            state.error,
            fallback: context.l10n.authErrorLoginFailed,
          ),
        );
      }
    });

    final loginLoading = ref.watch(loginNotifierProvider).isLoading;

    final mq = MediaQuery.of(context);
    final viewInsets = mq.viewInsets.bottom;
    final isSmall = mq.size.height < 680;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.only(bottom: viewInsets + 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(height: isSmall ? 16 : 28),
                          AuthHeader(
                            title: context.l10n.authButtonUstaadLogin,
                            subtitle: '',
                            isSmall: isSmall,
                            showBackButton: true,
                          ),
                          SizedBox(height: isSmall ? 20 : 32),
                          AuthTextField(
                            controller: _phoneCtrl,
                            label: context.l10n.authForgotPasswordPrompt,
                            hint: '03XXXXXXXXX',
                            keyboardType: TextInputType.phone,
                            prefixIcon: Icons.phone_outlined,
                            validator: _validatePhone,
                          ),
                          const SizedBox(height: 20),
                          AuthTextField(
                            controller: _passwordCtrl,
                            label: context.l10n.authFieldPassword,
                            prefixIcon: Icons.lock_outline_rounded,
                            obscureText: true,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _login(),
                          ),
                          const SizedBox(height: 8),
                          Align(
                            alignment: AlignmentDirectional.centerEnd,
                            child: GestureDetector(
                              onTap: () => context.push('/forgot-password'),
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 4),
                                child: Text(
                                  context.l10n.authButtonForgotPassword,
                                  style: TextStyle(
                                    color: kAuthAccent,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: isSmall ? 16 : 20),
                          AuthPrimaryButton(
                            label: context.l10n.authLoginWithPassword,
                            isLoading: loginLoading,
                            onPressed: _login,
                          ),
                        ],
                      ),
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
