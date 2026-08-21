import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pinput/pinput.dart';

import '../../../../core/theme/app_semantic_colors.dart';
import 'otp_input_section.dart' show ConsentApiSmsRetriever, otpLength;

/// Presentation widgets for the four CLIENT auth screens.
///
/// ## Why these are Client-specific
///
/// The shared `AuthTextField` / `AuthPrimaryButton` / `AuthHeader` /
/// `OtpInputSection` widgets are also used by the Ustaad login and Ustaad
/// registration screens, which are explicitly out of scope. They still carry
/// the pre-token orange literals; re-styling them would silently redesign the
/// Ustaad screens too. So the Client redesign lives here instead, and the
/// shared widgets are left byte-for-byte alone.
///
/// The one exception is `otp_input_section.dart`, where [otpLength] and
/// [ConsentApiSmsRetriever] were made public so this file reuses the very
/// same SMS-autofill mechanics and the very same backend-owned OTP length
/// rather than reimplementing (and drifting from) them. That change is purely
/// additive — no Ustaad screen renders differently because of it.
///
/// ## Colour
///
/// Every colour here is an [AppSemanticColors] token, so all four screens
/// follow the light and dark palettes with no page-level brightness checks.

/// The country code shown ahead of every Pakistani mobile field.
///
/// l10n-ignore: an ITU country calling code is the same string in every
/// language — the same treatment as the brand name itself.
const kPkDialCode = '+92';

/// The shape of a national mobile number, shown as a placeholder.
///
/// l10n-ignore: a digit mask, identical in every language.
const kPkPhoneHint = '3XX XXX XXXX';

/// Groups a national mobile number the way the design shows it —
/// `3213123323` → `321 312 3323`.
///
/// Accepts anything the app's phone validator does (`03…`, `+92…`, `92…`,
/// bare `3…`) and falls back to returning the digits untouched when the input
/// is not a recognisable 10-digit national number, so a surprising value is
/// still displayed rather than swallowed.
String formatPkNationalPhone(String raw) {
  var digits = raw.replaceAll(RegExp(r'\D'), '');
  if (digits.startsWith('0092')) {
    digits = digits.substring(4);
  } else if (digits.startsWith('92')) {
    digits = digits.substring(2);
  } else if (digits.startsWith('0')) {
    digits = digits.substring(1);
  }
  if (digits.length != 10) return digits;
  return '${digits.substring(0, 3)} ${digits.substring(3, 6)} '
      '${digits.substring(6)}';
}

/// Back arrow + heading + supporting line, in the design's proportions.
///
/// [icon] renders the small rounded tile the login screen shows beside its
/// heading; omit it for the screens that lead with the heading alone.
class ClientAuthHeader extends StatelessWidget {
  const ClientAuthHeader({
    super.key,
    required this.heading,
    required this.subtitle,
    this.icon,
    this.showBack = true,
  });

  final String heading;
  final String subtitle;
  final IconData? icon;
  final bool showBack;

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;

    final headingStyle = TextStyle(
      fontSize: 30,
      fontWeight: FontWeight.w800,
      height: 1.15,
      color: colors.textPrimary,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showBack) ...[
          // maybePop, so this is inert rather than crashing when the screen is
          // the first route on the stack.
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
          const SizedBox(height: 12),
        ],
        if (icon == null)
          Text(heading, style: headingStyle)
        else
          // Wrap, not Row: at a large text scale the heading needs the full
          // width, and the tile drops onto its own line instead of squeezing
          // the words.
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: colors.softTeal,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 26, color: colors.primary),
              ),
              Text(heading, style: headingStyle),
            ],
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

/// A field label sitting above its input, as the design shows them.
class ClientFieldLabel extends StatelessWidget {
  const ClientFieldLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: context.semanticColors.textSecondary,
        ),
      ),
    );
  }
}

/// The rounded outlined input the auth screens use.
///
/// ## When an error is allowed to appear
///
/// Never on first tap. `AutovalidateMode.onUserInteraction` cannot express
/// that: `TextFormField` marks a field "interacted" from its controller
/// listener, and a `TextEditingController` notifies on SELECTION changes as
/// well as text changes — so merely placing the caret in an empty field
/// validated it and printed "must be at least 8 characters" before a single
/// keystroke.
///
/// This field therefore tracks interaction itself:
///
///  * **pristine** — never focused, or focused but not yet left. Silent, no
///    matter how invalid the value is.
///  * **touched** — the field has been left at least once (blur). From then on
///    it shows its error, and re-validates on every keystroke so a correction
///    clears the message live.
///  * **submitted** — the form was submitted; [forceError] turns every
///    invalid field visible at once, without waiting to be blurred.
///
/// ## The outline never turns red
///
/// The border stays `controlBorder` when idle and `primary` when focused,
/// exactly as when valid. An invalid value is communicated by a line of
/// [AppSemanticColors.error] text underneath, which is quieter and does not
/// fight the focus treatment. This is why the decoration below sets every
/// error border to the same colours as the normal ones rather than leaving
/// Flutter's red defaults in place.
class ClientTextField extends StatefulWidget {
  const ClientTextField({
    super.key,
    required this.controller,
    this.hint,
    this.keyboardType = TextInputType.text,
    this.textInputAction = TextInputAction.next,
    this.obscureText = false,
    this.validator,
    this.onChanged,
    this.onFieldSubmitted,
    this.enabled = true,
    this.prefix,
    this.suffix,
    this.inputFormatters,
    this.autofillHints,
    this.forceError = false,
    this.focusNode,
  });

  /// Set by the page after a rejected submit: shows this field's error even
  /// if it was never focused. Independent of whether the CTA is enabled —
  /// a disabled button and a visible error are different questions.
  final bool forceError;

  /// Optional; one is created and owned here when not supplied, because blur
  /// is what promotes a field from pristine to touched.
  final FocusNode? focusNode;

  final TextEditingController controller;
  final String? hint;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final bool obscureText;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onFieldSubmitted;
  final bool enabled;
  final Widget? prefix;
  final Widget? suffix;
  final List<TextInputFormatter>? inputFormatters;
  final Iterable<String>? autofillHints;

  @override
  State<ClientTextField> createState() => _ClientTextFieldState();
}

class _ClientTextFieldState extends State<ClientTextField> {
  FocusNode? _ownedFocusNode;
  FocusNode get _focusNode =>
      widget.focusNode ?? (_ownedFocusNode ??= FocusNode());

  /// True once the field has been left after the user actually put something
  /// in it. Tapping in is not enough, and neither is tapping straight back
  /// out again — the brief states the error belongs to "entered invalid data,
  /// then moved away", not to passing through.
  bool _touched = false;

  /// Whether a keystroke has ever landed. Tracked separately from the text
  /// itself because a field can be non-empty from a prefilled draft, which is
  /// not the user having typed anything.
  bool _edited = false;
  late String _lastText;

  @override
  void initState() {
    super.initState();
    _lastText = widget.controller.text;
    _focusNode.addListener(_onFocusChange);
    // Deliberately not `addListener` on the controller for the touched flag:
    // a TextEditingController notifies on SELECTION changes too, so a bare tap
    // would count as an edit. `onChanged` fires on text only, and this
    // listener exists purely to catch programmatic/formatter-driven changes.
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    _focusNode.removeListener(_onFocusChange);
    _ownedFocusNode?.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (widget.controller.text != _lastText) {
      _lastText = widget.controller.text;
      _edited = true; // no setState: nothing visible changes until blur
    }
  }

  void _onFocusChange() {
    // Promotion happens on blur, never on focus.
    if (!_focusNode.hasFocus && !_touched && _edited) {
      setState(() => _touched = true);
    }
  }

  /// Phone numbers and passwords are Latin/numeric values. Under Urdu they
  /// would otherwise render right-aligned with the cursor on the wrong side,
  /// so those field types stay left-to-right whatever the app language —
  /// the same rule the shared `AuthTextField` applies.
  bool get _forcesLtr =>
      widget.obscureText ||
      widget.keyboardType == TextInputType.phone ||
      widget.keyboardType == TextInputType.number;

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;
    final showErrors = widget.forceError || _touched;

    OutlineInputBorder border(Color color, double width) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: color, width: width),
    );

    // The same borders in every state. Flutter swaps to errorBorder/
    // focusedErrorBorder the moment a validator returns a message; pointing
    // both at the normal colours is what keeps an invalid field from turning
    // red while still letting the message render underneath.
    final idle = border(colors.controlBorder, 1);
    final focused = border(colors.primary, 1.6);

    return TextFormField(
      controller: widget.controller,
      focusNode: _focusNode,
      enabled: widget.enabled,
      obscureText: widget.obscureText,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      textDirection: _forcesLtr ? TextDirection.ltr : null,
      textAlign: _forcesLtr ? TextAlign.left : TextAlign.start,
      // The gate is on DISPLAY, never on the validator: `disabled` means the
      // field simply does not validate itself, so nothing shows until either
      // this field is touched or the page calls `Form.validate()` on submit.
      // The validator itself always tells the truth — suppressing it would
      // make `validate()` return true for an empty form and let the request
      // go out.
      autovalidateMode: showErrors
          ? AutovalidateMode.always
          : AutovalidateMode.disabled,
      validator: widget.validator,
      onChanged: widget.onChanged,
      onFieldSubmitted: widget.onFieldSubmitted,
      inputFormatters: widget.inputFormatters,
      autofillHints: widget.autofillHints,
      style: TextStyle(fontSize: 16, color: colors.textPrimary),
      cursorColor: colors.primary,
      decoration: InputDecoration(
        hintText: widget.hint,
        hintStyle: TextStyle(fontSize: 16, color: colors.textSecondary),
        filled: true,
        fillColor: widget.enabled ? colors.surface : colors.surfaceSubtle,
        isDense: false,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 18,
        ),
        prefixIcon: widget.prefix,
        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        suffixIcon: widget.suffix,
        suffixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        enabledBorder: idle,
        focusedBorder: focused,
        disabledBorder: border(colors.border, 1),
        errorBorder: idle,
        focusedErrorBorder: focused,
        errorStyle: TextStyle(fontSize: 12.5, color: colors.error),
      ),
    );
  }
}

/// The `+92 │ 3XX XXX XXXX` field from the design — the dial code sits inside
/// the same rounded box as the input, separated by a hairline rule.
class ClientPhoneField extends StatelessWidget {
  const ClientPhoneField({
    super.key,
    required this.controller,
    this.validator,
    this.onChanged,
    this.onFieldSubmitted,
    this.textInputAction = TextInputAction.next,
    this.enabled = true,
    this.forceError = false,
    this.focusNode,
  });

  final TextEditingController controller;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onFieldSubmitted;
  final TextInputAction textInputAction;
  final bool enabled;
  final FocusNode? focusNode;

  /// See [ClientTextField.forceError].
  final bool forceError;

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;

    return ClientTextField(
      controller: controller,
      hint: kPkPhoneHint,
      keyboardType: TextInputType.phone,
      textInputAction: textInputAction,
      validator: validator,
      onChanged: onChanged,
      onFieldSubmitted: onFieldSubmitted,
      enabled: enabled,
      forceError: forceError,
      focusNode: focusNode,
      autofillHints: const [AutofillHints.telephoneNumberNational],
      prefix: Padding(
        padding: const EdgeInsetsDirectional.only(start: 18, end: 14),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              kPkDialCode,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(width: 14),
            Container(width: 1, height: 24, color: colors.border),
          ],
        ),
      ),
    );
  }
}

/// A password field with the design's textual `Show` / `Hide` action.
///
/// The toggle only flips [obscureText]; the controller is never touched, so
/// the typed value always survives showing and hiding it.
class ClientPasswordField extends StatefulWidget {
  const ClientPasswordField({
    super.key,
    required this.controller,
    required this.showLabel,
    required this.hideLabel,
    this.hint,
    this.validator,
    this.onChanged,
    this.onFieldSubmitted,
    this.textInputAction = TextInputAction.next,
    this.forceError = false,
    this.focusNode,
  });

  final TextEditingController controller;

  /// See [ClientTextField.forceError].
  final bool forceError;

  /// The localized in-field action label ("Show").
  final String showLabel;

  /// The localized in-field action label ("Hide").
  final String hideLabel;

  final String? hint;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onFieldSubmitted;
  final TextInputAction textInputAction;
  final FocusNode? focusNode;

  @override
  State<ClientPasswordField> createState() => _ClientPasswordFieldState();
}

class _ClientPasswordFieldState extends State<ClientPasswordField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;

    return ClientTextField(
      controller: widget.controller,
      hint: widget.hint,
      obscureText: _obscure,
      keyboardType: TextInputType.visiblePassword,
      textInputAction: widget.textInputAction,
      validator: widget.validator,
      onChanged: widget.onChanged,
      onFieldSubmitted: widget.onFieldSubmitted,
      forceError: widget.forceError,
      focusNode: widget.focusNode,
      suffix: Padding(
        padding: const EdgeInsetsDirectional.only(start: 8, end: 16),
        child: Semantics(
          button: true,
          toggled: !_obscure,
          child: InkWell(
            onTap: () => setState(() => _obscure = !_obscure),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: Text(
                _obscure ? widget.showLabel : widget.hideLabel,
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
    );
  }
}

/// The full-width filled CTA.
///
/// Disabled and loading are distinct states: disabled means "the form is not
/// valid yet" and paints from the theme's muted surface; loading means "a
/// request is in flight" and additionally blocks a second tap.
class ClientPrimaryButton extends StatelessWidget {
  const ClientPrimaryButton({
    super.key,
    required this.label,
    required this.isLoading,
    required this.onPressed,
  });

  final String label;
  final bool isLoading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;
    final enabled = onPressed != null && !isLoading;

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: enabled ? onPressed : null,
        style:
            ElevatedButton.styleFrom(
              backgroundColor: colors.primary,
              foregroundColor: colors.onPrimary,
              // The muted "form not ready" treatment from the design — a real
              // palette surface rather than a translucent brand colour, so it
              // reads correctly in dark mode too.
              disabledBackgroundColor: colors.surfaceSubtle,
              disabledForegroundColor: colors.textSecondary,
              elevation: 0,
              minimumSize: const Size.fromHeight(58),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ).copyWith(
              overlayColor: WidgetStateProperty.resolveWith(
                (states) => states.contains(WidgetState.pressed)
                    ? colors.primaryPressed
                    : null,
              ),
            ),
        child: isLoading
            ? SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: colors.onPrimary,
                ),
              )
            : Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
  }
}

/// The full-width outlined secondary action ("Login with OTP").
class ClientSecondaryButton extends StatelessWidget {
  const ClientSecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: colors.textPrimary,
          backgroundColor: colors.surface,
          side: BorderSide(color: colors.controlBorder),
          minimumSize: const Size.fromHeight(56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 2,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

/// A hairline rule with a centred word — the design's `———— OR ————`.
class ClientDivider extends StatelessWidget {
  const ClientDivider({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;
    final line = Expanded(child: Divider(color: colors.border, height: 1));

    return Row(
      children: [
        line,
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: colors.textSecondary,
            ),
          ),
        ),
        line,
      ],
    );
  }
}

/// A quiet prompt followed by a brand-coloured action — the footer pattern
/// shared by the login and registration screens.
class ClientFooterAction extends StatelessWidget {
  const ClientFooterAction({
    super.key,
    required this.prompt,
    required this.action,
    required this.onPressed,
  });

  final String prompt;
  final String action;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;

    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          prompt,
          style: TextStyle(fontSize: 15, color: colors.textSecondary),
        ),
        const SizedBox(width: 6),
        Semantics(
          button: true,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: Text(
                action,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: colors.primary,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The soft information panel from the registration design.
class ClientInfoBox extends StatelessWidget {
  const ClientInfoBox({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: colors.softTeal,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.shield_outlined, size: 20, color: colors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 14,
                height: 1.4,
                color: colors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The OTP boxes from the design.
///
/// Uses the same [Pinput] + [ConsentApiSmsRetriever] combination and the same
/// backend-owned [otpLength] as the shared `OtpInputSection`, so SMS
/// autofill, auto-advance and backspace behave identically — only the box
/// styling and the surrounding layout differ.
class ClientOtpField extends StatefulWidget {
  const ClientOtpField({
    super.key,
    required this.onChanged,
    required this.onCompleted,
    this.hasError = false,
  });

  final ValueChanged<String> onChanged;
  final ValueChanged<String> onCompleted;
  final bool hasError;

  @override
  State<ClientOtpField> createState() => _ClientOtpFieldState();
}

class _ClientOtpFieldState extends State<ClientOtpField> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  final _smsRetriever = ConsentApiSmsRetriever();

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _smsRetriever.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;

    // Sized from the window rather than a LayoutBuilder: these boxes sit
    // inside the scaffold's IntrinsicHeight, and a LayoutBuilder cannot report
    // intrinsic dimensions. Subtracting the scaffold's own gutters gives the
    // same answer without measuring.
    const gap = 10.0;
    final available = MediaQuery.sizeOf(context).width - 48;
    final boxWidth = ((available - gap * (otpLength - 1)) / otpLength).clamp(
      36.0,
      62.0,
    );

    final base = PinTheme(
      width: boxWidth,
      height: boxWidth * 1.15,
      textStyle: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: colors.textPrimary,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.controlBorder),
      ),
    );

    return Directionality(
      // The boxes hold digits and must fill left-to-right even in Urdu,
      // otherwise the first digit typed lands in the rightmost box.
      textDirection: TextDirection.ltr,
      child: Pinput(
        length: otpLength,
        controller: _controller,
        focusNode: _focusNode,
        autofocus: true,
        smsRetriever: _smsRetriever,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        separatorBuilder: (_) => const SizedBox(width: gap),
        defaultPinTheme: base,
        focusedPinTheme: base.copyWith(
          decoration: base.decoration!.copyWith(
            border: Border.all(color: colors.primary, width: 1.6),
          ),
        ),
        submittedPinTheme: base,
        errorPinTheme: base.copyWith(
          decoration: base.decoration!.copyWith(
            border: Border.all(color: colors.error, width: 1.6),
          ),
        ),
        forceErrorState: widget.hasError,
        onChanged: widget.onChanged,
        onCompleted: widget.onCompleted,
      ),
    );
  }
}

/// The page skeleton every Client auth screen sits in: a semantic background,
/// safe area, a scroll fallback that clears the keyboard inset, and a maximum
/// content width so a tablet gets a phone-width form rather than a stretched
/// one.
class ClientAuthScaffold extends StatelessWidget {
  const ClientAuthScaffold({super.key, required this.child, this.footer});

  final Widget child;

  /// Pinned to the bottom of the viewport when the content is short, and
  /// pushed below the content when it is not — which is what keeps a CTA
  /// reachable on a small screen at a large text scale.
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;

    return Scaffold(
      backgroundColor: colors.background,
      // The scroll view below owns the keyboard inset, so Scaffold must not
      // also resize — otherwise the content is shortened twice.
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final keyboard = MediaQuery.viewInsetsOf(context).bottom;
            final horizontal = constraints.maxWidth < 360 ? 20.0 : 24.0;

            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.only(bottom: keyboard),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: horizontal),
                      child: IntrinsicHeight(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SizedBox(height: 12),
                            child,
                            if (footer != null) ...[
                              const Spacer(),
                              const SizedBox(height: 24),
                              footer!,
                            ],
                            const SizedBox(height: 24),
                          ],
                        ),
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
