import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pinput/pinput.dart';
import 'package:smart_auth/smart_auth.dart';

import 'auth_primary_button.dart';

const _otpLength = 6;
const _otpValidity = Duration(minutes: 5);
const _resendCooldown = Duration(seconds: 60);

/// Reads the OTP via Android's SMS User Consent API — a system consent
/// dialog appears when a matching SMS arrives, no `READ_SMS`/`RECEIVE_SMS`
/// permission and no app-signature hash required (unlike the SMS Retriever
/// API). Every call already catches its own errors internally, so a failure
/// here (iOS, no Play Services, user dismissed the dialog) just means
/// autofill silently doesn't happen — manual entry is unaffected either way.
class _ConsentApiSmsRetriever implements SmsRetriever {
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
  final _smsRetriever = _ConsentApiSmsRetriever();
  Timer? _ticker;
  Duration _remaining = Duration.zero;

  DateTime get _requestedAt => widget.expiresAt.subtract(_otpValidity);

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
    final expired = _remaining <= Duration.zero;
    final secondsSinceRequest =
        DateTime.now().difference(_requestedAt).inSeconds;
    final canResend = secondsSinceRequest >= _resendCooldown.inSeconds;

    final defaultTheme = PinTheme(
      width: 46,
      height: 52,
      textStyle: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: kAuthDark,
      ),
      decoration: BoxDecoration(
        color: kAuthBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kAuthBorder),
      ),
    );
    final focusedTheme = defaultTheme.copyWith(
      decoration: defaultTheme.decoration!.copyWith(
        border: Border.all(color: kAuthAccent, width: 1.5),
      ),
    );
    final errorTheme = defaultTheme.copyWith(
      decoration: defaultTheme.decoration!.copyWith(
        border: Border.all(color: const Color(0xFFEF4444), width: 1.5),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Pinput(
          length: _otpLength,
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
        const SizedBox(height: 16),
        Center(
          child: expired
              ? Column(
                  children: [
                    const Text(
                      'Code expire ho gaya hai. Naya code mangwayein.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFFEF4444), fontSize: 13),
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
                      'Code ${_formatRemaining(_remaining)} mein expire hoga',
                      style: const TextStyle(fontSize: 13, color: kAuthGray),
                    ),
                    const SizedBox(height: 8),
                    canResend
                        ? _ResendLink(
                            enabled: !widget.resendInFlight,
                            loading: widget.resendInFlight,
                            onTap: widget.onResend,
                          )
                        : Text(
                            'Code dobara bhejein (${_resendCooldown.inSeconds - secondsSinceRequest}s)',
                            style: const TextStyle(
                              fontSize: 13,
                              color: kAuthGray,
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
    if (loading) {
      return const SizedBox(
        height: 20,
        width: 20,
        child: CircularProgressIndicator(strokeWidth: 2, color: kAuthAccent),
      );
    }
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: const Padding(
        padding: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        child: Text(
          'Code dobara bhejein',
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: kAuthAccent,
          ),
        ),
      ),
    );
  }
}
