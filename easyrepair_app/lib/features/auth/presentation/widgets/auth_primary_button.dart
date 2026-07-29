import 'package:flutter/material.dart';

const kAuthAccent = Color(0xFFDB6234);
const kAuthDark = Color(0xFF1A1A1A);
const kAuthGray = Color(0xFF6B7280);
const kAuthBorder = Color(0xFFE2E8F0);
const kAuthBg = Color(0xFFF9FAFB);

/// Shared primary CTA for every auth screen — consolidates the near-identical
/// private `_PrimaryButton` that used to be copy-pasted per auth page file.
/// Large touch target (52px tall), explicit disabled/loading states, and
/// scales with the system font size instead of clipping at large text sizes.
class AuthPrimaryButton extends StatelessWidget {
  final String label;
  final bool isLoading;
  final VoidCallback? onPressed;

  const AuthPrimaryButton({
    super.key,
    required this.label,
    required this.isLoading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !isLoading;
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: enabled ? onPressed : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: kAuthAccent,
          foregroundColor: Colors.white,
          disabledBackgroundColor: kAuthAccent.withAlpha(120),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
      ),
    );
  }
}

/// A lighter-weight secondary/outline button — used for the "Ustaad Login"
/// redirect action and the OTP/password toggle on the Worker login page.
class AuthSecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;

  const AuthSecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: kAuthAccent,
          side: const BorderSide(color: kAuthAccent, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 2,
          style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
