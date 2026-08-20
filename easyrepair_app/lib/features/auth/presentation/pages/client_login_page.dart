import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/failure_messages.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/l10n/l10n_extensions.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../core/theme/app_semantic_colors.dart';
import '../../domain/repositories/auth_repository.dart';
import '../providers/auth_otp_providers.dart';
import '../providers/client_password_providers.dart';
import '../widgets/client_auth_widgets.dart';
import '../widgets/otp_input_section.dart'
    show otpLength, otpResendCooldownDuration, otpValidityDuration;
import 'client_register_page.dart';

/// Which of the two login methods the page is currently showing.
///
/// This is local UI state, not navigation: both methods live on this one
/// screen, so switching between them never pushes or pops a route.
enum ClientLoginMode { password, otp }

/// SCREEN 1 — Client login, with BOTH login methods on one screen.
///
/// * [ClientLoginMode.password] — phone + password + Forgot Password, the
///   default.
/// * [ClientLoginMode.otp] — phone + six OTP boxes + expiry + resend, entered
///   by tapping "Login with OTP" and left again by tapping "Login with
///   Password".
///
/// Nothing about authentication changed: the password submit still goes
/// through [ClientPasswordLoginNotifier] → `POST /auth/client/password-login`,
/// the code request still goes through [otpRequestNotifierProvider] with
/// `OtpPurpose.clientLoginRegister`, and the OTP submit still goes through
/// [clientOtpAuthNotifierProvider] → `POST /auth/client/otp-login`. The OTP
/// length, its validity and the resend cooldown are the shared backend-owned
/// constants in `otp_input_section.dart`.
///
/// Every colour is an [AppSemanticColors] token, so this screen follows the
/// light and dark palettes with no brightness checks of its own.
class ClientLoginPage extends ConsumerStatefulWidget {
  const ClientLoginPage({super.key});

  static const route = '/auth/client';

  @override
  ConsumerState<ClientLoginPage> createState() => _ClientLoginPageState();
}

class _ClientLoginPageState extends ConsumerState<ClientLoginPage> {
  // Two forms, not one: "Login with OTP" must validate the phone WITHOUT
  // complaining that the password — which OTP mode does not use — is empty.
  final _phoneFormKey = GlobalKey<FormState>();
  final _passwordFormKey = GlobalKey<FormState>();

  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  ClientLoginMode _mode = ClientLoginMode.password;
  String _otp = '';
  bool _requestInFlight = false;

  /// Set when a submit is attempted, so every invalid field reveals its error
  /// at once instead of waiting to be visited and left. Kept apart from the
  /// CTA-enabled calculation below: whether the button is tappable and whether
  /// an error is on screen are two different questions.
  bool _phoneSubmitted = false;
  bool _passwordSubmitted = false;

  /// Recomputes the expiry/cooldown labels once a second. It only runs while
  /// there is something counting down, and stops itself when there is not —
  /// a permanently ticking setState would rebuild this screen forever.
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    // otpRequestNotifierProvider is a global, non-autoDispose provider shared
    // by every OTP screen and never reset by any of them. Clearing it on entry
    // stops a code requested earlier in this session from rendering this page
    // in its "code sent" state on the very first frame, with a countdown that
    // belongs to a different number. State only — this never sends anything.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(otpRequestNotifierProvider.notifier).reset();
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  // ── Backend-authoritative time ──────────────────────────────────────────
  //
  // Everything below is derived from the expiry the backend returned. There is
  // no locally-assumed 5-minute clock, so the countdown self-corrects across
  // time spent backgrounded and can never outlive the code it describes.

  DateTime? get _expiresAt => ref.read(otpRequestNotifierProvider).valueOrNull;

  Duration get _remaining {
    final expiresAt = _expiresAt;
    if (expiresAt == null) return Duration.zero;
    final left = expiresAt.difference(DateTime.now());
    return left.isNegative ? Duration.zero : left;
  }

  bool get _codeLive => _expiresAt != null && _remaining > Duration.zero;
  bool get _codeExpired => _expiresAt != null && _remaining <= Duration.zero;

  /// Seconds left on the backend's resend cooldown, anchored on the request
  /// time that the expiry implies.
  int get _cooldownRemaining {
    final expiresAt = _expiresAt;
    if (expiresAt == null) return 0;
    final requestedAt = expiresAt.subtract(otpValidityDuration);
    final elapsed = DateTime.now().difference(requestedAt).inSeconds;
    final left = otpResendCooldownDuration.inSeconds - elapsed;
    return left > 0 ? left : 0;
  }

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

  // ── Button state ────────────────────────────────────────────────────────

  /// Read with `watch` — both are only consulted while building, and the
  /// buttons must repaint the moment a request starts or finishes.
  bool get _verifyInFlight =>
      ref.watch(clientOtpAuthNotifierProvider).isLoading;

  bool get _passwordLoginInFlight =>
      ref.watch(clientPasswordLoginNotifierProvider).isLoading;

  bool get _phoneLooksValid => kPkPhonePattern.hasMatch(_phoneCtrl.text.trim());

  /// Password mode: a plausible number, a non-empty password, nothing in
  /// flight. The form's own validators remain the authority on submit.
  bool get _canPasswordLogin =>
      _phoneLooksValid && _passwordCtrl.text.isNotEmpty;

  /// OTP mode: a plausible number, a full code, a code that has not expired,
  /// nothing in flight.
  bool get _canOtpLogin =>
      _phoneLooksValid && _otp.length == otpLength && _codeLive;

  // ── Actions ─────────────────────────────────────────────────────────────

  Future<void> _passwordLogin() async {
    // `read`, not `watch`: this runs from a tap, outside build.
    if (ref.read(clientPasswordLoginNotifierProvider).isLoading) return;
    setState(() {
      _phoneSubmitted = true;
      _passwordSubmitted = true;
    });
    final phoneOk = _phoneFormKey.currentState?.validate() ?? false;
    final passwordOk = _passwordFormKey.currentState?.validate() ?? false;
    if (!phoneOk || !passwordOk) return;
    await ref.read(clientPasswordLoginNotifierProvider.notifier).login(
          _phoneCtrl.text.trim(),
          _passwordCtrl.text,
        );
  }

  /// Requests a code and, only on success, switches this page into OTP mode.
  ///
  /// Two gates come before the SMS. An invalid number never reaches the
  /// network at all — the phone form is validated first and its existing
  /// error is shown in place. A well-formed number is then classified by the
  /// backend (`/auth/client/phone-check`), because OTP login is for existing
  /// Clients only: a number with no Client account is sent to registration
  /// instead of being handed a code it could never log in with. That check is
  /// deliberately the backend's answer, not a guess from local state, and it
  /// reports a Worker-owned number exactly like an unknown one — so this
  /// branch can never leak which role owns a number.
  Future<void> _requestOtp() async {
    if (_requestInFlight) return;
    // Only the number is being submitted here — the password field, which is
    // still on screen in password mode, has no part in this and must not be
    // made to show an error by it.
    setState(() => _phoneSubmitted = true);
    if (!(_phoneFormKey.currentState?.validate() ?? false)) return;

    setState(() => _requestInFlight = true);
    try {
      final phone = _phoneCtrl.text.trim();
      final known = await ref
          .read(clientPhoneCheckNotifierProvider.notifier)
          .check(phone);
      if (!mounted || !known) return;
      if (ref.read(clientPhoneCheckNotifierProvider).valueOrNull !=
          ClientPhoneStatus.client) {
        _showNoClientAccount();
        return;
      }

      final sent = await ref.read(otpRequestNotifierProvider.notifier).request(
            phone,
            OtpPurpose.clientLoginRegister,
          );
      if (!mounted || !sent) return;
      setState(() {
        _mode = ClientLoginMode.otp;
        // A fresh code always starts from an empty box row.
        _otp = '';
      });
      _syncTicker();
    } finally {
      if (mounted) setState(() => _requestInFlight = false);
    }
  }

  Future<void> _otpLogin() async {
    if (!_canOtpLogin ||
        ref.read(clientOtpAuthNotifierProvider).isLoading) {
      return;
    }
    // A phone and a code. Login carries no name — see ClientOtpLoginDto.
    await ref
        .read(clientOtpAuthNotifierProvider.notifier)
        .verify(_phoneCtrl.text.trim(), _otp);
  }

  /// Back to password mode. Keeps the phone AND anything already typed into
  /// the password field, drops the OTP entry state, and requests nothing.
  void _usePassword() {
    setState(() {
      _mode = ClientLoginMode.password;
      _otp = '';
    });
    ref.read(otpRequestNotifierProvider.notifier).reset();
    _syncTicker();
  }

  /// A code belongs to the number it was sent to. Editing the number therefore
  /// invalidates it: the countdown is dropped, the typed digits are cleared,
  /// and OTP mode falls back to its "request a code" state.
  ///
  /// Deliberately state-only — it must never re-request, or correcting a
  /// single digit would burn an SMS send.
  void _onPhoneChanged(String _) {
    final hadRequest = ref.read(otpRequestNotifierProvider).valueOrNull != null;
    if (hadRequest) {
      ref.read(otpRequestNotifierProvider.notifier).reset();
    }
    setState(() {
      if (hadRequest) _otp = '';
    });
    _syncTicker();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(clientPasswordLoginNotifierProvider, (_, state) {
      if (state is AsyncError) _showError(state.error);
    });
    ref.listen(clientOtpAuthNotifierProvider, (_, state) {
      if (state is AsyncError) _showError(state.error);
    });
    ref.listen(otpRequestNotifierProvider, (_, state) {
      if (state is AsyncError) _showError(state.error);
    });
    ref.listen(clientPhoneCheckNotifierProvider, (_, state) {
      if (state is AsyncError) _showError(state.error);
    });

    final l10n = context.l10n;
    final isOtpMode = _mode == ClientLoginMode.otp;

    return ClientAuthScaffold(
      footer: ClientFooterAction(
        prompt: l10n.authClientNewHere,
        action: l10n.authClientCreateAccountTitle,
        onPressed: () => context.push(ClientRegisterPage.route),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClientAuthHeader(
            heading: l10n.authClientLoginHeading,
            subtitle: l10n.authClientLoginSubtitle,
            icon: Icons.waving_hand_rounded,
          ),
          const SizedBox(height: 28),
          ClientFieldLabel(l10n.authFieldMobileNumberTitle),
          Form(
            key: _phoneFormKey,
            child: ClientPhoneField(
              controller: _phoneCtrl,
              forceError: _phoneSubmitted,
              validator: (v) => validateClientPhone(context, v),
              // Stays editable in OTP mode — a mistyped number is the
              // commonest reason to come back to this field.
              onChanged: _onPhoneChanged,
              textInputAction:
                  isOtpMode ? TextInputAction.done : TextInputAction.next,
            ),
          ),
          if (isOtpMode) ..._otpMode(l10n) else ..._passwordMode(l10n),
        ],
      ),
    );
  }

  // ── Password mode ───────────────────────────────────────────────────────

  List<Widget> _passwordMode(AppLocalizations l10n) {
    final colors = context.semanticColors;

    return [
      const SizedBox(height: 18),
      ClientFieldLabel(l10n.authFieldPassword),
      Form(
        key: _passwordFormKey,
        child: ClientPasswordField(
          controller: _passwordCtrl,
          forceError: _passwordSubmitted,
          hint: l10n.authFieldPassword,
          showLabel: l10n.authClientPasswordShow,
          textInputAction: TextInputAction.done,
          validator: (v) => (v == null || v.isEmpty)
              ? l10n.authValidationPasswordRequired
              : null,
          onChanged: (_) => setState(() {}),
          onFieldSubmitted: (_) => _passwordLogin(),
        ),
      ),
      const SizedBox(height: 12),
      Align(
        alignment: AlignmentDirectional.centerEnd,
        child: _TextAction(
          label: l10n.authClientForgotPassword,
          // The Client-only password-reset flow that already existed.
          onPressed: () => context.push('/auth/client/forgot-password'),
        ),
      ),
      const SizedBox(height: 16),
      ClientPrimaryButton(
        label: l10n.authClientLoginButton,
        isLoading: _passwordLoginInFlight,
        onPressed: _canPasswordLogin ? _passwordLogin : null,
      ),
      const SizedBox(height: 22),
      ClientDivider(label: l10n.authOr),
      const SizedBox(height: 22),
      ClientSecondaryButton(
        label: l10n.authClientOtpLoginButton,
        // Switches THIS page into OTP mode — no route is pushed.
        onPressed: _requestInFlight ? null : _requestOtp,
      ),
      const SizedBox(height: 12),
      Text(
        l10n.authClientOtpHelp,
        style: TextStyle(
          fontSize: 14,
          height: 1.4,
          color: colors.textSecondary,
        ),
      ),
    ];
  }

  // ── OTP mode ────────────────────────────────────────────────────────────

  List<Widget> _otpMode(AppLocalizations l10n) {
    final colors = context.semanticColors;
    final hasCode = _expiresAt != null;
    final hasVerifyError = ref.watch(clientOtpAuthNotifierProvider) is AsyncError;

    return [
      if (hasCode) ...[
        const SizedBox(height: 24),
        ClientOtpField(
          // A new request means a new code: rebuilding on the expiry drops the
          // digits typed for the previous one instead of carrying them over.
          key: ValueKey(_expiresAt),
          hasError: hasVerifyError,
          onChanged: (v) => setState(() => _otp = v),
          onCompleted: (v) {
            setState(() => _otp = v);
            _otpLogin();
          },
        ),
        const SizedBox(height: 16),
        _ExpiryLine(expired: _codeExpired, remaining: _remaining),
        const SizedBox(height: 10),
        _ResendRow(
          prompt: l10n.authClientResendPrompt,
          action: l10n.authClientResendAction,
          cooldownRemaining: _cooldownRemaining,
          inFlight: _requestInFlight,
          onResend: _requestOtp,
        ),
        const SizedBox(height: 20),
        ClientPrimaryButton(
          label: l10n.authClientLoginButton,
          isLoading: _verifyInFlight,
          onPressed: _canOtpLogin ? _otpLogin : null,
        ),
      ] else ...[
        // The number was edited, so the previous code no longer applies. The
        // user stays in OTP mode but has to ask for a new code explicitly.
        const SizedBox(height: 24),
        ClientPrimaryButton(
          label: l10n.authClientOtpLoginButton,
          isLoading: _requestInFlight,
          onPressed: _phoneLooksValid ? _requestOtp : null,
        ),
        const SizedBox(height: 12),
        Text(
          l10n.authClientOtpHelp,
          style: TextStyle(
            fontSize: 14,
            height: 1.4,
            color: colors.textSecondary,
          ),
        ),
      ],
      const SizedBox(height: 16),
      Center(
        child: _TextAction(
          label: l10n.authClientLoginWithPassword,
          onPressed: _usePassword,
        ),
      ),
    ];
  }

  /// Shown when the number has no Client account. Points at registration
  /// rather than silently creating one, and says nothing about which role
  /// (if any) actually owns the number.
  void _showNoClientAccount() {
    if (!mounted) return;
    final l10n = context.l10n;
    final colors = context.semanticColors;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(l10n.authClientNoAccountFound),
          action: SnackBarAction(
            label: l10n.authClientCreateAccountTitle,
            textColor: colors.onPrimary,
            onPressed: () => context.push(ClientRegisterPage.route),
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

/// "Code expires in MM:SS", or the expired notice once it has run out.
class _ExpiryLine extends StatelessWidget {
  const _ExpiryLine({required this.expired, required this.remaining});

  final bool expired;
  final Duration remaining;

  String get _clock {
    final minutes = remaining.inMinutes.toString().padLeft(2, '0');
    final seconds = (remaining.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.semanticColors;

    return Text(
      expired ? l10n.authOtpExpired : l10n.authOtpExpiresIn(_clock),
      style: TextStyle(
        fontSize: 14,
        height: 1.4,
        color: expired ? colors.error : colors.textSecondary,
      ),
    );
  }
}

/// "Code nahi mila? Resend", or the cooldown label while the backend would
/// reject a resend anyway.
class _ResendRow extends StatelessWidget {
  const _ResendRow({
    required this.prompt,
    required this.action,
    required this.cooldownRemaining,
    required this.inFlight,
    required this.onResend,
  });

  final String prompt;
  final String action;
  final int cooldownRemaining;
  final bool inFlight;
  final VoidCallback onResend;

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;
    final ready = cooldownRemaining == 0 && !inFlight;

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          prompt,
          style: TextStyle(fontSize: 15, color: colors.textSecondary),
        ),
        const SizedBox(width: 6),
        if (inFlight)
          SizedBox(
            height: 18,
            width: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: colors.primary,
            ),
          )
        else
          _TextAction(
            label: cooldownRemaining == 0
                ? action
                : context.l10n.authOtpResendCooldown(cooldownRemaining),
            // The backend enforces the cooldown; mirroring it here only stops
            // the tap turning into a guaranteed rejection.
            onPressed: ready ? onResend : null,
          ),
      ],
    );
  }
}

/// A brand-coloured inline text button, muted when disabled.
class _TextAction extends StatelessWidget {
  const _TextAction({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;

    return Semantics(
      button: true,
      enabled: onPressed != null,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: onPressed == null ? colors.textSecondary : colors.primary,
            ),
          ),
        ),
      ),
    );
  }
}

/// The Pakistani mobile pattern the app has always accepted — `03…`, `+92…`,
/// `92…` or a bare `3…`. Mirrors the backend DTO's regex exactly; shared by
/// every Client auth screen so they can never disagree.
final RegExp kPkPhonePattern = RegExp(r'^(\+92|0092|92|0)?[3][0-9]{9}$');

/// Field validator for a Client phone input — same messages as before.
String? validateClientPhone(BuildContext context, String? value) {
  if (value == null || value.isEmpty) {
    return context.l10n.authValidationPhoneRequired;
  }
  if (!kPkPhonePattern.hasMatch(value.trim())) {
    return context.l10n.authValidationPhoneInvalid;
  }
  return null;
}
