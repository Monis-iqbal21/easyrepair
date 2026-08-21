import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../widgets/ustaad_register_widgets.dart';
import 'client_login_page.dart' show validateClientPhone;
import 'ustaad_register_step2_page.dart';

/// Ustaad registration, Step 1 of 4 — the account's own details.
///
/// Nothing is created here. "Send OTP" only requests a code through the
/// existing [otpRequestNotifierProvider] with the existing
/// `OtpPurpose.workerRegister`; the account is created at the end of Step 3,
/// once the trade is known.
class UstaadRegisterStep1Page extends ConsumerStatefulWidget {
  const UstaadRegisterStep1Page({super.key});

  static const route = '/auth/worker/register';

  @override
  ConsumerState<UstaadRegisterStep1Page> createState() =>
      _UstaadRegisterStep1PageState();
}

class _UstaadRegisterStep1PageState
    extends ConsumerState<UstaadRegisterStep1Page> {
  /// The CNIC shape the Ustaad profile form has always enforced.
  static final _cnicPattern = RegExp(r'^\d{5}-\d{7}-\d{1}$');

  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _cnicCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _nameFocus = FocusNode();
  final _phoneFocus = FocusNode();
  final _cnicFocus = FocusNode();
  final _passwordFocus = FocusNode();
  bool _sendInFlight = false;

  /// Set when a submit is attempted, so every invalid field reveals its error
  /// at once rather than only after being visited and left. Separate from the
  /// CTA-enabled calculation: a disabled button and a visible error answer two
  /// different questions.
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    // Re-entering the flow starts clean: a code requested earlier in this
    // session must not make Step 2 think one is already live for a different
    // number. State only — nothing is sent.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(otpRequestNotifierProvider.notifier).reset();
      ref.read(ustaadOtpVerifyNotifierProvider.notifier).reset();
      final draft = ref.read(ustaadRegistrationDraftProvider);
      // Coming back from Step 2 keeps what was typed; a fresh entry has
      // nothing to restore.
      _nameCtrl.text = draft.fullName;
      _phoneCtrl.text = draft.phone;
      _cnicCtrl.text = draft.cnicNumber;
      _passwordCtrl.text = draft.password;
      setState(() {});
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _cnicCtrl.dispose();
    _passwordCtrl.dispose();
    _nameFocus.dispose();
    _phoneFocus.dispose();
    _cnicFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    if (_sendInFlight) return;
    setState(() => _submitted = true);
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _sendInFlight = true);
    final phone = _phoneCtrl.text.trim();
    try {
      final sent = await ref
          .read(otpRequestNotifierProvider.notifier)
          .request(phone, OtpPurpose.workerRegister);
      if (!mounted || !sent) return;
      ref
          .read(ustaadRegistrationDraftProvider.notifier)
          .update(
            (d) => d.copyWith(
              fullName: _nameCtrl.text.trim(),
              phone: phone,
              cnicNumber: _cnicCtrl.text.trim(),
              password: _passwordCtrl.text,
            ),
          );
      context.push(UstaadRegisterStep2Page.route);
    } finally {
      if (mounted) setState(() => _sendInFlight = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(otpRequestNotifierProvider, (_, state) {
      if (state is AsyncError) _showError(state.error);
    });
    // Keeps the draft alive for as long as this step is on screen.
    ref.watch(ustaadRegistrationDraftProvider);

    final l10n = context.l10n;
    final colors = context.semanticColors;

    return UstaadStepScaffold(
      cta: ClientPrimaryButton(
        label: l10n.postJobNext,
        isLoading: _sendInFlight,
        // The visible CTA is the sole submit action. Keyboard actions only
        // move/dismiss focus and can never send an OTP or navigate.
        onPressed: _sendOtp,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            UstaadStepHeader(title: l10n.ustaadRegisterHeader, step: 1),
            const SizedBox(height: 20),
            Text(
              l10n.ustaadStep1Heading,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                height: 1.15,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              l10n.ustaadStepIndicator(1, 4),
              style: TextStyle(fontSize: 15, color: colors.textSecondary),
            ),
            const SizedBox(height: 22),
            ClientFieldLabel(l10n.ustaadFullNameLabel),
            ClientTextField(
              controller: _nameCtrl,
              focusNode: _nameFocus,
              forceError: _submitted,
              hint: l10n.ustaadFullNameHint,
              autofillHints: const [AutofillHints.name],
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? l10n.authValidationNameRequired
                  : null,
              onChanged: (_) => setState(() {}),
              onFieldSubmitted: (_) => _phoneFocus.requestFocus(),
            ),
            const SizedBox(height: 18),
            ClientFieldLabel(l10n.authFieldMobileNumberTitle),
            ClientPhoneField(
              controller: _phoneCtrl,
              focusNode: _phoneFocus,
              forceError: _submitted,
              validator: (v) => validateClientPhone(context, v),
              onChanged: (_) => setState(() {}),
              onFieldSubmitted: (_) => _cnicFocus.requestFocus(),
            ),
            const SizedBox(height: 18),
            ClientFieldLabel(l10n.ustaadCnicLabel),
            ClientTextField(
              controller: _cnicCtrl,
              focusNode: _cnicFocus,
              forceError: _submitted,
              hint: kCnicHint,
              keyboardType: TextInputType.number,
              inputFormatters: [_CnicInputFormatter()],
              validator: (v) => _cnicPattern.hasMatch((v ?? '').trim())
                  ? null
                  : l10n.workerCnicInvalid,
              onChanged: (_) => setState(() {}),
              onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
            ),
            const SizedBox(height: 18),
            ClientFieldLabel(l10n.ustaadCreatePasswordLabel),
            ClientPasswordField(
              controller: _passwordCtrl,
              focusNode: _passwordFocus,
              forceError: _submitted,
              hint: l10n.authClientPasswordHint,
              showLabel: l10n.authClientPasswordShow,
              hideLabel: l10n.authClientPasswordHide,
              textInputAction: TextInputAction.done,
              validator: (v) {
                if (v == null || v.isEmpty) {
                  return l10n.authValidationPasswordRequired;
                }
                if (v.length < 8) return l10n.authValidationPasswordTooShort;
                return null;
              },
              onChanged: (_) => setState(() {}),
              onFieldSubmitted: (_) => _passwordFocus.unfocus(),
            ),
            const SizedBox(height: 12),
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

/// Types the CNIC dashes as the Ustaad types the digits — the same formatter
/// the profile-completion form uses, so both screens accept identical input.
class _CnicInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final capped = digits.length > 13 ? digits.substring(0, 13) : digits;

    final buffer = StringBuffer();
    for (var i = 0; i < capped.length; i++) {
      if (i == 5 || i == 12) buffer.write('-');
      buffer.write(capped[i]);
    }
    final text = buffer.toString();

    // Put the caret back where the user's edit left it, expressed in digits
    // rather than characters. Pinning it to `text.length` — as this did —
    // sends it to the end of the field after EVERY keystroke, so correcting a
    // mistyped district code is impossible: the digit lands at the end and the
    // caret jumps away again. Counting digits is what survives the dashes this
    // formatter inserts, since they shift character offsets but not digits.
    final digitsBeforeCaret = newValue.text
        .substring(0, newValue.selection.end.clamp(0, newValue.text.length))
        .replaceAll(RegExp(r'\D'), '')
        .length;

    var offset = text.length;
    var seen = 0;
    for (var i = 0; i < text.length; i++) {
      if (text[i] != '-') seen++;
      if (seen == digitsBeforeCaret) {
        // Just past this digit — and past a dash that immediately follows it,
        // so typing the 5th digit leaves the caret after "42101-" ready for
        // the 6th rather than stranded before the separator.
        offset = i + 1;
        if (offset < text.length && text[offset] == '-') offset++;
        break;
      }
    }
    if (digitsBeforeCaret == 0) offset = 0;

    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: offset),
      composing: TextRange.empty,
    );
  }
}
