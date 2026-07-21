import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

const _kOrange = Color(0xFFDB6234);
const _kDark = Color(0xFF1A1A1A);
const _kGray = Color(0xFF6B7280);

/// Shown when a logged-in Ustaad's onboarding isn't APPROVED yet — on first
/// Worker Home load per app session (see [onboardingModalShownProvider]).
/// Has a close button; the worker can always reach the same destination
/// later via the persistent banner on Worker Home.
Future<void> showProfileCompletionModal(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _kOrange.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.assignment_ind_outlined,
                      color: _kOrange, size: 22),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.of(ctx).pop(),
                  child: const Icon(Icons.close_rounded, color: _kGray, size: 22),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Apni profile ki details complete karain.',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: _kDark,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'اپنی پروفائل کی تفصیلات مکمل کریں۔',
              textDirection: TextDirection.rtl,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: _kDark,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Profile complete honay ke baad hi aap jobs/bookings ke liye apply ya hire ho sakenge.',
              style: TextStyle(fontSize: 13.5, color: _kGray, height: 1.45),
            ),
            const SizedBox(height: 4),
            const Text(
              'پروفائل مکمل ہونے کے بعد ہی آپ jobs/bookings کے لیے apply یا hire ہو سکیں گے۔',
              textDirection: TextDirection.rtl,
              style: TextStyle(fontSize: 13, color: _kGray, height: 1.6),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  context.push('/worker/profile-completion');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kOrange,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Column(
                  children: [
                    Text(
                      'Complete Profile',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'پروفائل مکمل کریں',
                      textDirection: TextDirection.rtl,
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
