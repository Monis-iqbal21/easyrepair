import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pinput/pinput.dart';
import 'package:smart_auth/smart_auth.dart';

import '../../../../core/l10n/l10n_extensions.dart';
import '../../../../core/theme/app_semantic_colors.dart';

/// How many digits an OTP has.
///
/// Backend-owned: `AuthService` issues `crypto.randomInt(100000, 1000000)`
/// and every verify DTO validates `/^[0-9]{6}$/`, so this is a mirror of a
/// server constant, not a UI choice. Screens that render OTP boxes or say
/// "n-digit code" must read it from here rather than hardcoding a number.
const otpLength = 6;

/// How long a requested OTP stays valid — must match backend OTP_EXPIRY_MS.
const otpValidityDuration = Duration(minutes: 5);

/// The backend's resend cooldown — must match backend OTP_RESEND_COOLDOWN_MS.
const otpResendCooldownDuration = Duration(seconds: 60);

/// Reconstructs a still-valid OTP's `expiresAt` from a fresh
/// OTP_RESEND_TOO_SOON rejection's `retryAfterSeconds`.
///
/// Needed when the local `expiresAt` was lost (e.g. the OTP page was
/// remounted, which intentionally clears the request notifier so a stale
/// "code sent" state never blocks correcting the phone number — see the OTP
/// pages' `initState`) but the backend confirms a code requested less than a
/// minute ago is still live. The resend cooldown and the OTP's own validity
/// share one anchor (the request time), so the remaining validity is
/// recoverable from how much of the cooldown is left.
DateTime expiresAtFromRetryAfter(int retryAfterSeconds) {
  final elapsedSinceRequest =
      otpResendCooldownDuration - Duration(seconds: retryAfterSeconds);
  final requestedAt = DateTime.now().subtract(elapsedSinceRequest);
  return requestedAt.add(otpValidityDuration);
}

/// Reads the OTP via Android's SMS User Consent API — a system consent
/// dialog appears when a matching SMS arrives, no `READ_SMS`/`RECEIVE_SMS`
/// permission and no app-signature hash required (unlike the SMS Retriever
/// API). Every call already catches its own errors internally, so a failure
/// here (iOS, no Play Services, user dismissed the dialog) just means
/// autofill silently doesn't happen — manual entry is unaffected either way.
class ConsentApiSmsRetriever implements SmsRetriever {
  @override
  bool get listenForMultipleSms => false;

  @override
  Future<String?> getSmsCode() async {
    final result = await SmartAuth.instance.getSmsWithUserConsentApi();
    return result.hasData ? result.data!.code : null;
  }

  @override
  Future<void> dispose() => SmartAuth.instance.removeUserConsentApiListener();
}

/// The reusable "6 boxes + countdown + resend" block shared by every OTP
/// screen (Client login/register, Worker registration, Worker login).
///
/// The countdown is always derived from [expiresAt] — the backend's
/// authoritative expiry — recomputed every tick and every time the app
/// resumes from background, never from a locally-decrementing counter, so it
/// self-corrects for time spent backgrounded and never trusts the device
/// clock's drift across a long countdown.
class OtpInputSection extends StatefulWidget {
  final DateTime expiresAt;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onCompleted;
  final VoidCallback onResend;
  final bool resendInFlight;
  final bool hasError;

  const OtpInputSection({
    super.key,
    required this.expiresAt,
    required this.onChanged,
    required this.onCompleted,
    required this.onResend,
    required this.resendInFlight,
    this.hasError = false,
  });

  @override
  State<OtpInputSection> createState() => _OtpInputSectionState();
}

class _OtpInputSectionState extends State<OtpInputSection>
    with WidgetsBindingObserver {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  final _smsRetriever = ConsentApiSmsRetriever();
  Timer? _ticker;
  Duration _remaining = Duration.zero;

  DateTime get _requestedAt => widget.expiresAt.subtract(otpValidityDuration);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _recompute();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _recompute());
  }

  @override
  void didUpdateWidget(OtpInputSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.expiresAt != widget.expiresAt) {
      _controller.clear();
      _recompute();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The countdown is always derived from `expiresAt`, so simply
    // recomputing on resume is enough to correct for any time spent
    // backgrounded — no separate pause/resume bookkeeping needed.
    if (state == AppLifecycleState.resumed) {
      _recompute();
    }
  }

  void _recompute() {
    final remaining = widget.expiresAt.difference(DateTime.now());
    if (!mounted) return;
    setState(() {
      _remaining = remaining.isNegative ? Duration.zero : remaining;
    });
  }

  String _formatRemaining(Duration d) {
    final minutes = d.inMinutes.toString().padLeft(2, '0');
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    _smsRetriever.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;
    final expired = _remaining <= Duration.zero;
    final secondsSinceRequest = DateTime.now()
        .difference(_requestedAt)
        .inSeconds;
    final canResend =
        secondsSinceRequest >= otpResendCooldownDuration.inSeconds;

    final defaultTheme = PinTheme(
      width: 46,
      height: 52,
      textStyle: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: c.textPrimary,
      ),
      decoration: BoxDecoration(
        color: c.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.border),
      ),
    );
    final focusedTheme = defaultTheme.copyWith(
      decoration: defaultTheme.decoration!.copyWith(
        border: Border.all(color: c.primary, width: 1.5),
      ),
    );
    final errorTheme = defaultTheme.copyWith(
      decoration: defaultTheme.decoration!.copyWith(
        border: Border.all(color: c.error, width: 1.5),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // The OTP boxes are digits and must fill left-to-right even in Urdu,
        // otherwise the first digit typed lands in the rightmost box.
        Directionality(
          textDirection: TextDirection.ltr,
          child: Pinput(
            length: otpLength,
            controller: _controller,
            focusNode: _focusNode,
            autofocus: true,
            smsRetriever: _smsRetriever,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            defaultPinTheme: defaultTheme,
            focusedPinTheme: focusedTheme,
            submittedPinTheme: defaultTheme,
            errorPinTheme: errorTheme,
            forceErrorState: widget.hasError,
            onChanged: widget.onChanged,
            onCompleted: widget.onCompleted,
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: expired
              ? Column(
                  children: [
                    Text(
                      context.l10n.authOtpExpired,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: c.error, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    _ResendLink(
                      enabled: !widget.resendInFlight,
                      loading: widget.resendInFlight,
                      onTap: widget.onResend,
                    ),
                  ],
                )
              : Column(
                  children: [
                    Text(
                      context.l10n.authOtpExpiresIn(
                        _formatRemaining(_remaining),
                      ),
                      style: TextStyle(fontSize: 13, color: c.textSecondary),
                    ),
                    const SizedBox(height: 8),
                    canResend
                        ? _ResendLink(
                            enabled: !widget.resendInFlight,
                            loading: widget.resendInFlight,
                            onTap: widget.onResend,
                          )
                        : Text(
                            context.l10n.authOtpResendCooldown(
                              otpResendCooldownDuration.inSeconds -
                                  secondsSinceRequest,
                            ),
                            style: TextStyle(
                              fontSize: 13,
                              color: c.textSecondary,
                            ),
                          ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _ResendLink extends StatelessWidget {
  final bool enabled;
  final bool loading;
  final VoidCallback onTap;

  const _ResendLink({
    required this.enabled,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;
    if (loading) {
      return SizedBox(
        height: 20,
        width: 20,
        child: CircularProgressIndicator(strokeWidth: 2, color: c.primary),
      );
    }
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        child: Text(
          context.l10n.authOtpResend,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: c.primary,
          ),
        ),
      ),
    );
  }
}
