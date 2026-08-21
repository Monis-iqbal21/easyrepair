import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/failure_messages.dart';
import '../../../../core/l10n/l10n_extensions.dart';
import '../../../../core/theme/app_semantic_colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../widgets/client_auth_widgets.dart';
import '../widgets/otp_input_section.dart'
    show otpLength, otpResendCooldownDuration, otpValidityDuration;
import 'client_login_page.dart' show kPkPhonePattern, validateClientPhone;
import 'ustaad_login_page.dart';

// ── Providers ─────────────────────────────────────────────────────────────────

/// Holds the backend's authoritative OTP expiry once requested — mirrors
/// `OtpRequestNotifier` (used by the Client/Worker OTP screens) but calls the
/// separate Worker-only `/auth/forgot-password/request` endpoint, which is
/// backed by `PasswordResetOtp`, not `AuthOtp`.
final _forgotPasswordRequestProvider =
    AsyncNotifierProvider.autoDispose<_RequestNotifier, DateTime?>(
      _RequestNotifier.new,
    );

class _RequestNotifier extends AutoDisposeAsyncNotifier<DateTime?> {
  @override
  Future<DateTime?> build() async => null;

  Future<bool> request(String phone) async {
    // .copyWithPrevious carries the last known expiresAt through loading and
    // error states, so a resend that fails (e.g. a genuine SMS provider
    // hiccup) doesn't drop the already-showing OTP box back to the phone
    // form — see OtpRequestNotifier.request for the full rationale. The
    // backend's own rate-limit/cooldown are enumeration-safe here and never
    // surface as an error (they silently return the still-valid expiresAt),
    // so this only matters for genuine send failures.
    state = const AsyncLoading<DateTime?>().copyWithPrevious(state);
    final result = await ref
        .read(authRepositoryProvider)
        .forgotPasswordRequest(phone);
    return result.fold(
      (f) {
        state = AsyncError(f, StackTrace.current);
        return false;
      },
      (expiresAt) {
        state = AsyncData(expiresAt);
        return true;
      },
    );
  }
}

final _forgotPasswordResetProvider =
    AsyncNotifierProvider.autoDispose<_ResetNotifier, void>(_ResetNotifier.new);

class _ResetNotifier extends AutoDisposeAsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<bool> reset({
    required String phone,
    required String otp,
    required String newPassword,
  }) async {
    state = const AsyncLoading();
    final result = await ref
        .read(authRepositoryProvider)
        .forgotPasswordReset(phone: phone, otp: otp, newPassword: newPassword);
    return result.fold(
      (f) {
        state = AsyncError(f, StackTrace.current);
        return false;
      },
      (_) {
        state = const AsyncData(null);
        return true;
      },
    );
  }
}

// ── Page ──────────────────────────────────────────────────────────────────────

/// Which part of the reset the screen is showing.
enum _ResetStage { phone, code, newPassword, done }

/// Ustaad-only password recovery — Client accounts never reach this page
/// (linked only from [UstaadLoginPage]) and never receive a reset OTP even if
/// a Client phone number is entered here: the backend silently no-ops for
/// non-Worker phones. Clients have their own page and their own endpoints at
/// `/auth/client/forgot-password`, so the two roles can never cross over or
/// return to the wrong login screen.
///
/// ## The code is verified by the reset call, not before it
///
/// `POST /auth/forgot-password/reset` takes the phone, the code and the new
/// password together and verifies the code there. This screen therefore shows
/// the code and the password as two steps for readability, but does not
/// pretend to have "verified" anything in between — inventing a client-side
/// verified flag would be a fiction the backend never agreed to. The code is
/// held only until the single reset call that spends it.
class ForgotPasswordPage extends ConsumerStatefulWidget {
  const ForgotPasswordPage({super.key});

  static const route = '/forgot-password';

  @override
  ConsumerState<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends ConsumerState<ForgotPasswordPage> {
  final _phoneKey = GlobalKey<FormState>();
  final _passwordKey = GlobalKey<FormState>();
  final _phoneCtrl = TextEditingController();
  final _newPasswordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  _ResetStage _stage = _ResetStage.phone;
  String _otp = '';
  bool _sendInFlight = false;
  bool _resetInFlight = false;

  /// Set when a submit is attempted on the step in question, so every invalid
  /// field on it reveals its error at once rather than only after being
  /// visited and left. Two flags because the two steps are two forms — a
  /// rejected number must not pre-flag the password fields the user has not
  /// reached yet. Separate from the CTA-enabled calculations: a disabled
  /// button and a visible error answer two different questions.
  bool _phoneSubmitted = false;
  bool _passwordSubmitted = false;
  Timer? _ticker;

  @override
  void dispose() {
    _ticker?.cancel();
    _phoneCtrl.dispose();
    _newPasswordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  // ── Backend-authoritative time ──────────────────────────────────────────

  DateTime? get _expiresAt =>
      ref.read(_forgotPasswordRequestProvider).valueOrNull;

  Duration get _remaining {
    final expiresAt = _expiresAt;
    if (expiresAt == null) return Duration.zero;
    final left = expiresAt.difference(DateTime.now());
    return left.isNegative ? Duration.zero : left;
  }

  bool get _codeLive => _expiresAt != null && _remaining > Duration.zero;
  bool get _codeExpired => _expiresAt != null && _remaining <= Duration.zero;

  int get _cooldownRemaining {
    final expiresAt = _expiresAt;
    if (expiresAt == null) return 0;
    final requestedAt = expiresAt.subtract(otpValidityDuration);
    final elapsed = DateTime.now().difference(requestedAt).inSeconds;
    final left = otpResendCooldownDuration.inSeconds - elapsed;
    return left > 0 ? left : 0;
  }

  String get _clock {
    final minutes = _remaining.inMinutes.toString().padLeft(2, '0');
    final seconds = (_remaining.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  /// Ticks only while something is counting down, and stops itself when
  /// nothing is.
  void _syncTicker() {
    final counting = _remaining > Duration.zero || _cooldownRemaining > 0;
    if (counting) {
      _ticker ??= Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() {});
        if (_remaining <= Duration.zero && _cooldownRemaining <= 0) {
          _ticker?.cancel();
          _ticker = null;
        }
      });
    } else {
      _ticker?.cancel();
      _ticker = null;
    }
  }

  // ── Actions ─────────────────────────────────────────────────────────────

  /// Editing the number invalidates the code requested for the previous one
  /// and returns the screen to the phone step. State-only — it never
  /// re-requests, or correcting one digit would burn an SMS.
  void _onPhoneChanged(String _) {
    if (ref.read(_forgotPasswordRequestProvider).valueOrNull != null) {
      ref.invalidate(_forgotPasswordRequestProvider);
      setState(() {
        _otp = '';
        _stage = _ResetStage.phone;
      });
      _syncTicker();
    }
  }

  Future<void> _sendCode({bool advance = true}) async {
    if (_sendInFlight) return;
    // The phone form only exists on the phone step. A resend from the code
    // step has nothing left to validate — the number was already accepted to
    // get here — so a null form state means "already valid", not "invalid".
    final phoneForm = _phoneKey.currentState;
    if (phoneForm != null) {
      setState(() => _phoneSubmitted = true);
      if (!phoneForm.validate()) return;
    }
    if (!kPkPhonePattern.hasMatch(_phoneCtrl.text.trim())) return;
    setState(() => _sendInFlight = true);
    try {
      final sent = await ref
          .read(_forgotPasswordRequestProvider.notifier)
          .request(_phoneCtrl.text.trim());
      if (!mounted || !sent) return;
      setState(() {
        // A new code always starts from an empty box row.
        _otp = '';
        if (advance) _stage = _ResetStage.code;
      });
      _syncTicker();
    } finally {
      if (mounted) setState(() => _sendInFlight = false);
    }
  }

  Future<void> _resetPassword() async {
    if (_resetInFlight) return;
    setState(() => _passwordSubmitted = true);
    if (!(_passwordKey.currentState?.validate() ?? false)) return;
    if (_otp.length != otpLength || !_codeLive) return;

    setState(() => _resetInFlight = true);
    try {
      final ok = await ref
          .read(_forgotPasswordResetProvider.notifier)
          .reset(
            phone: _phoneCtrl.text.trim(),
            otp: _otp,
            newPassword: _newPasswordCtrl.text,
          );
      if (!mounted || !ok) return;
      setState(() {
        // Spent. There is nothing left to hold, and the session is
        // deliberately NOT established — the backend issues no tokens here, so
        // the Ustaad logs in with the password they just chose.
        _otp = '';
        _stage = _ResetStage.done;
      });
      _ticker?.cancel();
      _ticker = null;
    } finally {
      if (mounted) setState(() => _resetInFlight = false);
    }
  }

  /// Back walks the stages rather than the navigator: leaving the code step
  /// should return to the number, not drop the whole reset. Only the first
  /// step pops the route.
  void _back() {
    switch (_stage) {
      case _ResetStage.phone:
        Navigator.of(context).maybePop();
      case _ResetStage.code:
        setState(() => _stage = _ResetStage.phone);
      case _ResetStage.newPassword:
        setState(() => _stage = _ResetStage.code);
      case _ResetStage.done:
        _goToLogin();
    }
  }

  void _goToLogin() {
    // Replace, not pop: the reset is finished, so it must not stay behind the
    // login screen on the stack.
    context.go(UstaadLoginPage.route);
  }

  // ── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    ref.listen(_forgotPasswordRequestProvider, (_, s) {
      if (s is AsyncError) {
        _showError(s.error, context.l10n.authErrorCodeSendFailed);
      }
    });
    ref.listen(_forgotPasswordResetProvider, (_, s) {
      if (s is AsyncError) {
        _showError(s.error, context.l10n.authErrorPasswordChangeFailed);
      }
    });

    final l10n = context.l10n;

    return switch (_stage) {
      _ResetStage.phone => _phoneStep(l10n),
      _ResetStage.code => _codeStep(l10n),
      _ResetStage.newPassword => _passwordStep(l10n),
      _ResetStage.done => _successStep(l10n),
    };
  }

  Widget _phoneStep(AppLocalizations l10n) {
    return ClientAuthScaffold(
      footer: ClientPrimaryButton(
        label: l10n.ustaadSendOtpButton,
        isLoading: _sendInFlight,
        onPressed: kPkPhonePattern.hasMatch(_phoneCtrl.text.trim())
            ? _sendCode
            : null,
      ),
      child: Form(
        key: _phoneKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Heading(
              title: l10n.ustaadForgotHeading,
              subtitle: l10n.ustaadForgotSubtitle,
              onBack: _back,
            ),
            const SizedBox(height: 26),
            ClientFieldLabel(l10n.authFieldMobileNumberTitle),
            ClientPhoneField(
              controller: _phoneCtrl,
              forceError: _phoneSubmitted,
              validator: (v) => validateClientPhone(context, v),
              onChanged: (v) {
                setState(() {});
                _onPhoneChanged(v);
              },
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _sendCode(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _codeStep(AppLocalizations l10n) {
    final colors = context.semanticColors;
    final cooldown = _cooldownRemaining;

    return ClientAuthScaffold(
      footer: ClientPrimaryButton(
        label: l10n.ustaadVerifyButton,
        isLoading: false,
        // Nothing is verified server-side yet — this only carries a complete,
        // unexpired code forward to the password step, which spends it.
        onPressed: _otp.length == otpLength && _codeLive
            ? () => setState(() => _stage = _ResetStage.newPassword)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Heading(
            title: l10n.ustaadForgotOtpHeading,
            subtitle: l10n.ustaadForgotOtpBody(
              formatPkNationalPhone(_phoneCtrl.text),
            ),
            onBack: _back,
          ),
          const SizedBox(height: 26),
          ClientOtpField(
            // A new request means a new code: rebuilding on the expiry drops
            // digits typed for the previous one.
            key: ValueKey(_expiresAt),
            onChanged: (v) => setState(() => _otp = v),
            onCompleted: (v) => setState(() => _otp = v),
          ),
          const SizedBox(height: 16),
          Text(
            _codeExpired ? l10n.authOtpExpired : l10n.authOtpExpiresIn(_clock),
            style: TextStyle(
              fontSize: 14,
              height: 1.4,
              color: _codeExpired ? colors.error : colors.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                l10n.authClientResendPrompt,
                style: TextStyle(fontSize: 15, color: colors.textSecondary),
              ),
              const SizedBox(width: 6),
              if (_sendInFlight)
                SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: colors.primary,
                  ),
                )
              else
                Semantics(
                  button: true,
                  enabled: cooldown == 0,
                  child: InkWell(
                    // The backend enforces the cooldown; mirroring it here
                    // only stops the tap becoming a guaranteed rejection.
                    onTap: cooldown == 0
                        ? () => _sendCode(advance: false)
                        : null,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 6,
                      ),
                      child: Text(
                        cooldown == 0
                            ? l10n.authClientResendAction
                            : l10n.authOtpResendCooldown(cooldown),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: cooldown == 0
                              ? colors.primary
                              : colors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _passwordStep(AppLocalizations l10n) {
    final canSubmit =
        _newPasswordCtrl.text.length >= 8 &&
        _confirmCtrl.text == _newPasswordCtrl.text &&
        _otp.length == otpLength &&
        _codeLive;

    return ClientAuthScaffold(
      footer: ClientPrimaryButton(
        label: l10n.ustaadChangePasswordButton,
        isLoading: _resetInFlight,
        onPressed: canSubmit ? _resetPassword : null,
      ),
      child: Form(
        key: _passwordKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Heading(
              title: l10n.ustaadForgotNewPasswordHeading,
              subtitle: '',
              onBack: _back,
            ),
            const SizedBox(height: 26),
            ClientFieldLabel(l10n.ustaadNewPasswordLabel),
            ClientPasswordField(
              controller: _newPasswordCtrl,
              forceError: _passwordSubmitted,
              hint: l10n.authClientPasswordHint,
              showLabel: l10n.authClientPasswordShow,
              hideLabel: l10n.authClientPasswordHide,
              validator: (v) {
                if (v == null || v.isEmpty) {
                  return l10n.authNewPasswordRequired;
                }
                if (v.length < 8) return l10n.authValidationPasswordTooShort;
                return null;
              },
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 18),
            ClientFieldLabel(l10n.ustaadConfirmPasswordLabel),
            ClientPasswordField(
              controller: _confirmCtrl,
              forceError: _passwordSubmitted,
              hint: l10n.authClientConfirmPasswordHint,
              showLabel: l10n.authClientPasswordShow,
              hideLabel: l10n.authClientPasswordHide,
              textInputAction: TextInputAction.done,
              validator: (v) {
                if (v == null || v.isEmpty) {
                  return l10n.authValidationConfirmPasswordRequired;
                }
                if (v != _newPasswordCtrl.text) {
                  return l10n.authValidationPasswordsDoNotMatch;
                }
                return null;
              },
              onChanged: (_) => setState(() {}),
              onFieldSubmitted: (_) => _resetPassword(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _successStep(AppLocalizations l10n) {
    final colors = context.semanticColors;

    return ClientAuthScaffold(
      footer: ClientPrimaryButton(
        label: l10n.ustaadGoToLoginButton,
        isLoading: false,
        onPressed: _goToLogin,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 40),
          Center(
            child: Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: colors.softTeal,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.check_rounded, size: 48, color: colors.success),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            l10n.ustaadResetSuccessTitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              height: 1.2,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            l10n.ustaadResetSuccessBody,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              height: 1.45,
              color: colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  void _showError(Object? error, String fallback) {
    if (!mounted) return;
    final message = failureMessage(context.l10n, error, fallback: fallback);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

/// Back arrow, heading and supporting line — the same block every step opens
/// with, so the header does not jump between stages.
class _Heading extends StatelessWidget {
  const _Heading({required this.title, required this.subtitle, this.onBack});

  final String title;
  final String subtitle;

  /// Stage-aware: the reset screen walks its own steps backwards before it
  /// pops the route. Null falls back to popping.
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          button: true,
          label: MaterialLocalizations.of(context).backButtonTooltip,
          child: InkResponse(
            onTap: onBack ?? () => Navigator.of(context).maybePop(),
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
        const SizedBox(height: 12),
        Text(
          title,
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w800,
            height: 1.15,
            color: colors.textPrimary,
          ),
        ),
        if (subtitle.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 15,
              height: 1.45,
              color: colors.textSecondary,
            ),
          ),
        ],
      ],
    );
  }
}
