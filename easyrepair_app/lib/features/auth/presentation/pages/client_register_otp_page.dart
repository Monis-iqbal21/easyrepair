import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/failure_messages.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/l10n/l10n_extensions.dart';
import '../../../../core/theme/app_semantic_colors.dart';
import '../../domain/repositories/auth_repository.dart';
import '../providers/auth_otp_providers.dart';
import '../providers/client_password_providers.dart';
import '../widgets/client_auth_widgets.dart';
import '../widgets/otp_input_section.dart'
    show otpLength, otpResendCooldownDuration, otpValidityDuration;
import 'client_account_ready_page.dart';
import 'client_register_page.dart';

/// SCREEN 3 — Client registration, OTP verification.
///
/// ## How the account is created
///
/// One call. `POST /auth/client/password-register` now takes the code
/// alongside the name and password, and the backend verifies it BEFORE
/// writing anything — so a rejected code leaves no account behind, and no
/// account ever exists in an unverified state holding tokens.
///
/// This replaces an earlier two-step sequence (create, then log in again by
/// OTP to prove the number), which only existed because the register endpoint
/// could not accept a code and the OTP endpoint could not accept a password.
/// Splitting login from registration removed the need for both halves of that
/// workaround.
///
/// ## Everything else is the existing OTP behaviour
///
/// The code length, the 5-minute validity, the 60-second resend cooldown and
/// the SMS autofill are all the shared constants and mechanics the Ustaad and
/// password-reset screens use — see `otp_input_section.dart`. The length in
/// particular is backend-owned ([otpLength]): the design mocks four boxes, but
/// `AuthService` issues six digits and every verify DTO rejects anything else,
/// so the screen renders [otpLength] boxes and the supporting line names that
/// same number.
class ClientRegisterOtpPage extends ConsumerStatefulWidget {
  const ClientRegisterOtpPage({super.key, required this.draft});

  static const route = '/auth/client/register/verify';

  final ClientRegistrationDraft draft;

  @override
  ConsumerState<ClientRegisterOtpPage> createState() =>
      _ClientRegisterOtpPageState();
}

class _ClientRegisterOtpPageState extends ConsumerState<ClientRegisterOtpPage> {
  String _otp = '';
  bool _verifyInFlight = false;
  bool _resendInFlight = false;
  bool _hasError = false;

  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    // Drives the resend cooldown label. The remaining time is always derived
    // from the request's authoritative expiry, never from a local counter, so
    // it self-corrects across backgrounding.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncTicker();
    });
  }

  /// Ticks only while a resend cooldown is actually running, and stops itself
  /// the moment it reaches zero. A permanently-running periodic setState would
  /// rebuild this screen once a second forever — and would mean the widget
  /// tree never settles, which is exactly what a test's pumpAndSettle waits
  /// for.
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

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  DateTime? get _expiresAt => ref.read(otpRequestNotifierProvider).valueOrNull;

  /// How long the current code is still good for, straight from the backend's
  /// expiry — never a locally-assumed five minutes.
  Duration get _remaining {
    final expiresAt = _expiresAt;
    if (expiresAt == null) return Duration.zero;
    final left = expiresAt.difference(DateTime.now());
    return left.isNegative ? Duration.zero : left;
  }

  bool get _codeLive => _expiresAt != null && _remaining > Duration.zero;
  bool get _codeExpired => _expiresAt != null && _remaining <= Duration.zero;

  /// Seconds left on the backend's resend cooldown, or zero when a resend is
  /// allowed. Anchored on the request time, which the expiry implies.
  int get _cooldownRemaining {
    final expiresAt = _expiresAt;
    if (expiresAt == null) return 0;
    final requestedAt = expiresAt.subtract(otpValidityDuration);
    final elapsed = DateTime.now().difference(requestedAt).inSeconds;
    final remaining = otpResendCooldownDuration.inSeconds - elapsed;
    return remaining > 0 ? remaining : 0;
  }

  Future<void> _verify() async {
    // An expired code is rejected by the backend anyway; refusing it here
    // keeps the button honest rather than firing a guaranteed failure.
    if (_otp.length != otpLength || !_codeLive || _verifyInFlight) return;
    setState(() {
      _verifyInFlight = true;
      _hasError = false;
    });
    try {
      final created = await ref
          .read(clientPasswordRegisterNotifierProvider.notifier)
          .register(
            fullName: widget.draft.fullName,
            phone: widget.draft.phone,
            password: widget.draft.password,
            otp: _otp,
          );
      if (!created) {
        if (mounted) setState(() => _hasError = true);
        return;
      }
      if (!mounted) return;
      // Navigated immediately, before the refreshed session resolves, so the
      // router's "logged-in user on an /auth route" rule never gets the chance
      // to bounce this flow to Home ahead of the success screen. The success
      // route lives under /client, where an authenticated Client is allowed to
      // be — no redirect rule was changed to make this work.
      context.go(
        ClientAccountReadyPage.route,
        extra: ClientAccountSummary(
          fullName: widget.draft.fullName,
          phone: widget.draft.phone,
        ),
      );
    } finally {
      if (mounted) setState(() => _verifyInFlight = false);
    }
  }

  /// The remaining validity as MM:SS, for the expiry line.
  String get _clock {
    final minutes = _remaining.inMinutes.toString().padLeft(2, '0');
    final seconds = (_remaining.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Future<void> _resend() async {
    if (_resendInFlight || _cooldownRemaining > 0) return;
    setState(() => _resendInFlight = true);
    try {
      await ref.read(otpRequestNotifierProvider.notifier).request(
            widget.draft.phone,
            OtpPurpose.clientLoginRegister,
          );
    } finally {
      if (mounted) {
        setState(() {
          _resendInFlight = false;
          _otp = '';
        });
        _syncTicker();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(otpRequestNotifierProvider, (_, state) {
      if (state is AsyncError) _showError(state.error);
    });
    ref.listen(clientPasswordRegisterNotifierProvider, (_, state) {
      if (state is AsyncError) _showError(state.error);
    });
    ref.listen(clientOtpAuthNotifierProvider, (_, state) {
      if (state is AsyncError) _showError(state.error);
    });

    final l10n = context.l10n;
    final colors = context.semanticColors;
    final cooldown = _cooldownRemaining;

    return ClientAuthScaffold(
      footer: ClientPrimaryButton(
        label: l10n.authClientVerifyButton,
        isLoading: _verifyInFlight,
        onPressed:
            _otp.length == otpLength && _codeLive ? _verify : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClientAuthHeader(
            heading: l10n.authClientVerifyHeading,
            subtitle: l10n.authClientVerifySentTo(
              otpLength,
              formatPkNationalPhone(widget.draft.phone),
            ),
          ),
          const SizedBox(height: 26),
          ClientOtpField(
            // A new request means a new code: rebuilding on the expiry drops
            // the digits typed for the previous one.
            key: ValueKey(_expiresAt),
            hasError: _hasError,
            onChanged: (v) => setState(() {
              _otp = v;
              _hasError = false;
            }),
            onCompleted: (v) {
              setState(() => _otp = v);
              _verify();
            },
          ),
          const SizedBox(height: 16),
          Text(
            _codeExpired
                ? l10n.authOtpExpired
                : l10n.authOtpExpiresIn(_clock),
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
              if (_resendInFlight)
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
                    // just stops the tap turning into a guaranteed rejection.
                    onTap: cooldown == 0 ? _resend : null,
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
