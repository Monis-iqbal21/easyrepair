import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/failure_messages.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/l10n/l10n_extensions.dart';
import '../../domain/repositories/auth_repository.dart';
import '../providers/auth_otp_providers.dart';
import '../widgets/client_auth_widgets.dart';
import 'client_login_page.dart';
import 'client_register_otp_page.dart';

/// SCREEN 2 — Client registration, step 1.
///
/// Collects the account's details and requests the verification code. Nothing
/// is created here: "Send OTP" only calls the existing
/// `POST /auth/otp/request` with the existing `CLIENT_LOGIN_REGISTER` purpose,
/// exactly as the previous combined Client auth page did, and hands the typed
/// values to [ClientRegisterOtpPage], which performs the account creation.
///
/// Validation is unchanged: a non-empty name, the same Pakistani mobile
/// pattern the backend DTO enforces, a minimum of 8 password characters, and
/// a confirmation that must match.
class ClientRegisterPage extends ConsumerStatefulWidget {
  const ClientRegisterPage({super.key});

  static const route = '/auth/client/register';

  @override
  ConsumerState<ClientRegisterPage> createState() => _ClientRegisterPageState();
}

class _ClientRegisterPageState extends ConsumerState<ClientRegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _sendInFlight = false;

  @override
  void initState() {
    super.initState();
    // otpRequestNotifierProvider is a global, non-autoDispose provider shared
    // by every OTP screen and is never reset by any of them. Clearing it on
    // entry stops an OTP requested earlier in this session from making the
    // next screen think a code is already live for a different number.
    // State only — this never sends anything.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(otpRequestNotifierProvider.notifier).reset();
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  /// Drives the CTA's enabled treatment only — the form's validators remain
  /// the authority on submit.
  bool get _canSubmit =>
      _nameCtrl.text.trim().isNotEmpty &&
      kPkPhonePattern.hasMatch(_phoneCtrl.text.trim()) &&
      _passwordCtrl.text.length >= 8 &&
      _confirmCtrl.text == _passwordCtrl.text;

  Future<void> _sendOtp() async {
    if (_sendInFlight || !_formKey.currentState!.validate()) return;
    setState(() => _sendInFlight = true);
    final phone = _phoneCtrl.text.trim();
    try {
      final sent = await ref.read(otpRequestNotifierProvider.notifier).request(
            phone,
            OtpPurpose.clientLoginRegister,
          );
      if (!mounted || !sent) return;
      context.push(
        ClientRegisterOtpPage.route,
        extra: ClientRegistrationDraft(
          fullName: _nameCtrl.text.trim(),
          phone: phone,
          password: _passwordCtrl.text,
        ),
      );
    } finally {
      if (mounted) setState(() => _sendInFlight = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(otpRequestNotifierProvider, (_, state) {
      if (state is AsyncError) _showError(state.error);
    });

    final l10n = context.l10n;

    return ClientAuthScaffold(
      footer: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClientPrimaryButton(
            label: l10n.authClientSendOtpButton,
            isLoading: _sendInFlight,
            onPressed: _canSubmit ? _sendOtp : null,
          ),
          const SizedBox(height: 18),
          ClientFooterAction(
            prompt: l10n.authClientHaveAccount,
            action: l10n.authClientLoginAction,
            // pop rather than push: this screen was pushed from login, so
            // going "back to login" is exactly the existing stack unwinding.
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go(ClientLoginPage.route);
              }
            },
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClientAuthHeader(
              heading: l10n.authClientCreateAccountTitle,
              subtitle: l10n.authClientRegisterSubtitle,
            ),
            const SizedBox(height: 26),
            ClientFieldLabel(l10n.authClientFullNameLabel),
            ClientTextField(
              controller: _nameCtrl,
              hint: l10n.authHintFullName,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.name],
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? l10n.authValidationNameRequired
                  : null,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 18),
            ClientFieldLabel(l10n.authFieldMobileNumber),
            ClientPhoneField(
              controller: _phoneCtrl,
              validator: (v) => validateClientPhone(context, v),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 18),
            ClientFieldLabel(l10n.authClientCreatePasswordLabel),
            ClientPasswordField(
              controller: _passwordCtrl,
              hint: l10n.authClientPasswordHint,
              showLabel: l10n.authClientPasswordShow,
              validator: (v) {
                if (v == null || v.isEmpty) {
                  return l10n.authValidationPasswordRequired;
                }
                if (v.length < 8) return l10n.authValidationPasswordTooShort;
                return null;
              },
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 18),
            ClientFieldLabel(l10n.authClientConfirmPasswordLabel),
            ClientPasswordField(
              controller: _confirmCtrl,
              hint: l10n.authClientConfirmPasswordHint,
              showLabel: l10n.authClientPasswordShow,
              textInputAction: TextInputAction.done,
              validator: (v) {
                if (v == null || v.isEmpty) {
                  return l10n.authValidationConfirmPasswordRequired;
                }
                if (v != _passwordCtrl.text) {
                  return l10n.authValidationPasswordsDoNotMatch;
                }
                return null;
              },
              onChanged: (_) => setState(() {}),
              onFieldSubmitted: (_) => _sendOtp(),
            ),
            const SizedBox(height: 22),
            ClientInfoBox(message: l10n.authClientAddressNotice),
          ],
        ),
      ),
    );
  }

  void _showError(Object? error) {
    if (!mounted) return;
    final l10n = context.l10n;
    final message = error is SmsSendFailure
        ? l10n.authErrorOtpSendFailed
        : failureMessage(l10n, error, fallback: l10n.authErrorGeneric);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

/// What step 1 hands to step 2 — the values the user typed, carried in the
/// route's `extra` rather than in a provider so they cannot outlive the flow.
class ClientRegistrationDraft {
  const ClientRegistrationDraft({
    required this.fullName,
    required this.phone,
    required this.password,
  });

  final String fullName;
  final String phone;
  final String password;
}
