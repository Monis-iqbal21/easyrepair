import 'package:flutter/material.dart';
import '../../../../core/theme/app_semantic_colors.dart';

class AuthTextField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final bool obscureText;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;
  final TextInputAction textInputAction;
  final void Function(String)? onFieldSubmitted;
  final IconData? prefixIcon;
  final bool enabled;
  final ValueChanged<String>? onChanged;

  const AuthTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.validator,
    this.textInputAction = TextInputAction.next,
    this.onFieldSubmitted,
    this.prefixIcon,
    this.enabled = true,
    this.onChanged,
  });

  @override
  State<AuthTextField> createState() => _AuthTextFieldState();
}

class _AuthTextFieldState extends State<AuthTextField> {
  late bool _obscure;

  @override
  void initState() {
    super.initState();
    _obscure = widget.obscureText;
  }

  /// Phone numbers, passwords and email addresses are Latin/numeric values.
  /// Under Urdu RTL they would render right-aligned with the cursor on the
  /// wrong side, so these field types stay left-to-right regardless of the
  /// app language. Ordinary text fields still follow the locale.
  bool get _forcesLtr =>
      widget.obscureText ||
      widget.keyboardType == TextInputType.phone ||
      widget.keyboardType == TextInputType.number ||
      widget.keyboardType == TextInputType.emailAddress ||
      widget.keyboardType == TextInputType.visiblePassword;

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;
    return TextFormField(
      controller: widget.controller,
      obscureText: _obscure,
      textDirection: _forcesLtr ? TextDirection.ltr : null,
      textAlign: _forcesLtr ? TextAlign.left : TextAlign.start,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      onFieldSubmitted: widget.onFieldSubmitted,
      onChanged: widget.onChanged,
      enabled: widget.enabled,
      validator: widget.validator,
      style: TextStyle(fontSize: 15, color: c.textPrimary),
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hint,
        labelStyle: TextStyle(fontSize: 14, color: c.textSecondary),
        hintStyle: TextStyle(fontSize: 14, color: c.textSecondary),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        filled: true,
        fillColor: c.surface,
        prefixIcon: widget.prefixIcon != null
            ? Icon(widget.prefixIcon, size: 20, color: c.textSecondary)
            : null,
        suffixIcon: widget.obscureText
            ? IconButton(
                icon: Icon(
                  _obscure
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: 20,
                  color: c.textSecondary,
                ),
                onPressed: () => setState(() => _obscure = !_obscure),
              )
            : null,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c.error, width: 1.5),
        ),
      ),
    );
  }
}
