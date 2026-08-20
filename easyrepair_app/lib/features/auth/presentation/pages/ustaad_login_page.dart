import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/failure_messages.dart';
import '../../../../core/l10n/l10n_extensions.dart';
import '../../../../core/theme/app_semantic_colors.dart';
import '../providers/auth_providers.dart';
import '../widgets/client_auth_widgets.dart';
import 'client_login_page.dart' show kPkPhonePattern, validateClientPhone;
import 'ustaad_register_step1_page.dart';

/// Ustaad login — phone + password, and nothing else.
///
/// Authentication only: there is no OTP option here (an Ustaad's SMS-code
/// login route was deliberately removed from the backend — see the note in
/// `auth.controller.ts`) and no name field. The submit still goes through the
/// existing [loginNotifierProvider] → `POST /auth/login`, which bcrypt-compares
/// the password and issues the normal tokens, so every account-status rule
/// (suspended, deactivated, deleted) keeps applying exactly as before.
///
/// The layout and the shared field widgets are the ones the Client auth
/// screens use, so the two roles look like one product; only the copy and the
/// reassurance box differ.
class UstaadLoginPage extends ConsumerStatefulWidget {
  const UstaadLoginPage({super.key});

  static const route = '/auth/worker/login';

  @override
  ConsumerState<UstaadLoginPage> createState() => _UstaadLoginPageState();
}

class _UstaadLoginPageState extends ConsumerState<UstaadLoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  /// Set when a submit is attempted, so every invalid field reveals its error
  /// at once rather than only after being visited and left. Separate from the
  /// CTA-enabled calculation: a disabled button and a visible error answer two
  /// different questions.
  bool _submitted = false;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  /// Drives the button's enabled treatment only — the form's own validators
  /// remain the authority on submit.
  bool get _canSubmit =>
      kPkPhonePattern.hasMatch(_phoneCtrl.text.trim()) &&
      _passwordCtrl.text.isNotEmpty;

  Future<void> _login() async {
    if (ref.read(loginNotifierProvider).isLoading) return;
    setState(() => _submitted = true);
    if (!(_formKey.currentState?.validate() ?? false)) return;
    await ref
        .read(loginNotifierProvider.notifier)
        .login(_phoneCtrl.text.trim(), _passwordCtrl.text);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(loginNotifierProvider, (_, state) {
      if (state is AsyncError) _showError(state.error);
    });

    final l10n = context.l10n;
    final colors = context.semanticColors;
    final isLoading = ref.watch(loginNotifierProvider).isLoading;

    return ClientAuthScaffold(
      footer: ClientFooterAction(
        prompt: l10n.ustaadLoginNewPrompt,
        action: l10n.ustaadLoginRegisterAction,
        onPressed: () => context.push(UstaadRegisterStep1Page.route),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _UstaadBrandHeader(
              title: l10n.workerRoleBadge,
              subtitle: l10n.ustaadLoginBrandSubtitle,
            ),
            const SizedBox(height: 18),
            Text(
              l10n.authButtonUstaadLogin,
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w800,
                height: 1.15,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              l10n.ustaadLoginSubtitle,
              style: TextStyle(
                fontSize: 15,
                height: 1.45,
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: 26),
            ClientFieldLabel(l10n.authFieldMobileNumberTitle),
            ClientPhoneField(
              controller: _phoneCtrl,
              forceError: _submitted,
              validator: (v) => validateClientPhone(context, v),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 18),
            ClientFieldLabel(l10n.authFieldPassword),
            ClientPasswordField(
              controller: _passwordCtrl,
              forceError: _submitted,
              hint: l10n.authFieldPassword,
              showLabel: l10n.authClientPasswordShow,
              textInputAction: TextInputAction.done,
              validator: (v) => (v == null || v.isEmpty)
                  ? l10n.authValidationPasswordRequired
                  : null,
              onChanged: (_) => setState(() {}),
              onFieldSubmitted: (_) => _login(),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: Semantics(
                button: true,
                child: InkWell(
                  // The Ustaad-only reset flow that already existed, backed by
                  // /auth/forgot-password/* — see ForgotPasswordPage.
                  onTap: () => context.push('/forgot-password'),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                    child: Text(
                      l10n.authClientForgotPassword,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: colors.primary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            ClientPrimaryButton(
              label: l10n.authClientLoginButton,
              isLoading: isLoading,
              onPressed: _canSubmit ? _login : null,
            ),
            const SizedBox(height: 20),
            ClientInfoBox(message: l10n.ustaadLoginInfoBox),
          ],
        ),
      ),
    );
  }

  void _showError(Object? error) {
    if (!mounted) return;
    final message = failureMessage(
      context.l10n,
      error,
      fallback: context.l10n.authErrorGeneric,
    );
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

/// The small "Ustaad / HandyGo par kaam lein" block that sits beside the back
/// arrow, as in the design.
class _UstaadBrandHeader extends StatelessWidget {
  const _UstaadBrandHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Semantics(
          button: true,
          label: MaterialLocalizations.of(context).backButtonTooltip,
          child: InkResponse(
            onTap: () => Navigator.of(context).maybePop(),
            radius: 24,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Icon(
                Icons.arrow_back_rounded,
                size: 24,
                color: colors.textPrimary,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(fontSize: 14, color: colors.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
