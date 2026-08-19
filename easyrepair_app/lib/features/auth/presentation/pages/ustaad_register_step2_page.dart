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
import '../providers/ustaad_registration_draft.dart';
import '../widgets/client_auth_widgets.dart';
import '../widgets/otp_input_section.dart'
    show otpLength, otpResendCooldownDuration, otpValidityDuration;
import '../widgets/ustaad_register_widgets.dart';
import 'ustaad_register_step3_page.dart';

/// Ustaad registration, Step 2 of 4 — proving the number.
///
/// Verifying here is permanent: `POST /auth/worker/otp-verify` consumes the
/// code and hands back a registration token, which is what Step 3 later
/// presents to create the account. That is why the Ustaad can spend as long as
/// they like on their profile without the 5-minute code expiring underneath
/// them, and why the raw code is never carried past this screen.
///
/// Six boxes, not the four the mock draws: the backend issues six digits and
/// every verify DTO rejects anything else. The length comes from the shared
/// [otpLength] constant so the two can never drift apart.
class UstaadRegisterStep2Page extends ConsumerStatefulWidget {
  const UstaadRegisterStep2Page({super.key});

  static const route = '/auth/worker/register/verify';

  @override
  ConsumerState<UstaadRegisterStep2Page> createState() =>
      _UstaadRegisterStep2PageState();
}

class _UstaadRegisterStep2PageState
    extends ConsumerState<UstaadRegisterStep2Page> {
  String _otp = '';
  bool _verifyInFlight = false;
  bool _resendInFlight = false;
  bool _hasError = false;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncTicker();
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  // ── Backend-authoritative time ──────────────────────────────────────────

  DateTime? get _expiresAt => ref.read(otpRequestNotifierProvider).valueOrNull;

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
  /// nothing is — a permanently ticking setState would rebuild forever.
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

  Future<void> _verify() async {
    // The OTP field auto-submits on the sixth digit AND the CTA can be
    // tapped; the in-flight flag is what stops the two turning into two
    // verifications of the same code (the second would always fail, since the
    // first consumed it).
    if (_otp.length != otpLength || !_codeLive || _verifyInFlight) return;
    setState(() {
      _verifyInFlight = true;
      _hasError = false;
    });
    try {
      final draft = ref.read(ustaadRegistrationDraftProvider);
      final token = await ref
          .read(ustaadOtpVerifyNotifierProvider.notifier)
          .verify(draft.phone, _otp);
      if (!mounted) return;
      if (token == null) {
        setState(() => _hasError = true);
        return;
      }
      // The code itself is deliberately not kept: it is spent, and the token
      // is what authorises the rest of the registration.
      ref.read(ustaadRegistrationDraftProvider.notifier).update(
            (d) => d.copyWith(
              registrationToken: token.token,
              registrationTokenExpiresAt: token.expiresAt,
            ),
          );
      context.push(UstaadRegisterStep3Page.route);
    } finally {
      if (mounted) setState(() => _verifyInFlight = false);
    }
  }

  Future<void> _resend() async {
    if (_resendInFlight || _cooldownRemaining > 0) return;
    setState(() => _resendInFlight = true);
    try {
      await ref.read(otpRequestNotifierProvider.notifier).request(
            ref.read(ustaadRegistrationDraftProvider).phone,
            OtpPurpose.workerRegister,
          );
    } finally {
      if (mounted) {
        setState(() {
          _resendInFlight = false;
          // A new code means the old digits are meaningless.
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
    ref.listen(ustaadOtpVerifyNotifierProvider, (_, state) {
      if (state is AsyncError) _showError(state.error);
    });

    final l10n = context.l10n;
    final colors = context.semanticColors;
    final draft = ref.watch(ustaadRegistrationDraftProvider);
    final cooldown = _cooldownRemaining;

    return UstaadStepScaffold(
      cta: ClientPrimaryButton(
        label: l10n.ustaadVerifyButton,
        isLoading: _verifyInFlight,
        onPressed: _otp.length == otpLength && _codeLive ? _verify : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          UstaadStepHeader(title: l10n.ustaadVerificationHeader, step: 2),
          const SizedBox(height: 20),
          Text(
            l10n.ustaadStep2Heading,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              height: 1.15,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.ustaadStep2Subtitle(formatPkNationalPhone(draft.phone)),
            style: TextStyle(
              fontSize: 15,
              height: 1.4,
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: 24),
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
                    // The backend enforces the cooldown; mirroring it here only
                    // stops the tap becoming a guaranteed rejection.
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
