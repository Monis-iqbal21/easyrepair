import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/worker_providers.dart';

const _kOrange = Color(0xFFDB6234);
const _kDark = Color(0xFF1A1A1A);
const _kGray = Color(0xFF6B7280);

/// Gate for worker actions that require an APPROVED profile (bid, apply,
/// go online). Shows the required bilingual message and returns false if the
/// worker isn't approved yet; returns true and does nothing otherwise, so
/// callers can write `if (!ensureApprovedOrWarn(context, ref)) return;`.
/// The backend independently enforces this too — this is just so the worker
/// gets an immediate, clear message instead of a network round-trip failure.
bool ensureApprovedOrWarn(BuildContext context, WidgetRef ref) {
  final profile = ref.read(workerProfileProvider).valueOrNull;
  if (profile != null && !profile.isOnboardingApproved) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Profile approval required before receiving jobs.\n'
          'Jobs hasil karne ke liye pehle profile approval zaroori hai.',
        ),
        backgroundColor: Color(0xFFDC2626),
        behavior: SnackBarBehavior.floating,
      ),
    );
    return false;
  }
  return true;
}

/// Full-panel replacement for a list's loading/data/error content when the
/// worker's profile isn't APPROVED yet — shown instead of "Something went
/// wrong" (New Jobs' own fetch would otherwise 403, and even where the fetch
/// itself doesn't error, an incomplete profile has nothing meaningful to
/// list). [romanUrdu]/[urdu] are the two required lines; the button always
/// opens the profile-completion page.
class ProfileIncompleteState extends StatelessWidget {
  final String romanUrdu;
  final String urdu;

  const ProfileIncompleteState({
    super.key,
    required this.romanUrdu,
    required this.urdu,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: Color(0xFFFFF0EB),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Icon(Icons.assignment_late_outlined, color: _kOrange, size: 32),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              romanUrdu,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: _kDark, height: 1.5, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              urdu,
              textAlign: TextAlign.center,
              textDirection: TextDirection.rtl,
              style: const TextStyle(fontSize: 13.5, color: _kGray, height: 1.7),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => context.push('/worker/profile-completion'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kOrange,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Complete Profile', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                    SizedBox(height: 1),
                    Text(
                      'پروفائل مکمل کریں',
                      textDirection: TextDirection.rtl,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
