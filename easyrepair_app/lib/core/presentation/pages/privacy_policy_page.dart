import 'package:flutter/material.dart';

import '../../l10n/l10n_extensions.dart';
import '../../theme/app_semantic_colors.dart';
import '../widgets/legal_english_only_notice.dart';

/// The page chrome here (app bar, back button, the English-only notice) is
/// localized like the rest of the app. The document itself is not: the
/// approved Privacy Policy text stays in English until professionally
/// translated Urdu and Roman Urdu versions are supplied. See
/// `docs/legal_translation_exclusions.md`.
///
/// SHARED SCREEN: reached from BOTH the Client and the Ustaad profile, and
/// presented identically to both. Only colour and type moved here — the
/// approved wording below is byte-for-byte what it was.
class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          context.l10n.settingsPrivacyPolicy,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: c.textPrimary,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const LegalEnglishOnlyNotice(),
              const SizedBox(height: 16),
              // The document is English, so it reads left-to-right whatever
              // the app's language is.
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: c.border),
                ),
                child: const Directionality(
                  textDirection: TextDirection.ltr,
                  child: _PolicyContent(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── L10N-LEGAL-BODY:START ────────────────────────────────────────────────────
// Everything below is the approved Privacy Policy text. It is deliberately
// NOT localized and NOT machine-translated: legal wording needs a
// professionally approved Urdu / Roman Urdu translation before it can ship in
// another language. The hard-coded string audit reports this block as
// Category 5, not as missed migration work.
// See docs/legal_translation_exclusions.md.

class _PolicyContent extends StatelessWidget {
  const _PolicyContent();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        _LastUpdated(date: 'June 2, 2026'),
        SizedBox(height: 20),
        _BodyText(
          'Handygo operates an on-demand home repair and service booking '
          'platform. This Privacy Policy explains our information '
          'collection, use, storage, and sharing practices. By using '
          'Handygo, you agree to this policy.',
        ),
        SizedBox(height: 24),
        _Heading('1. Information We Collect'),
        _BulletPoint(
          title: 'Account & Profile',
          body: 'Name, profile photo, phone number, and email.',
        ),
        _BulletPoint(
          title: 'Address & Job Location',
          body: 'Details you provide when posting jobs or requesting services.',
        ),
        _BulletPoint(
          title: 'Precise Location',
          body:
              'Your device location when the app is in use, or continuously while you are an active worker.',
        ),
        _BulletPoint(
          title: 'Booking & Job Details',
          body: 'Service type, description, status, and history.',
        ),
        _BulletPoint(
          title: 'Chat Messages',
          body: 'Messages exchanged between clients and workers.',
        ),
        _BulletPoint(
          title: 'Media Attachments',
          body:
              'Images, videos, and audio notes shared through chat or job submissions.',
        ),
        _BulletPoint(
          title: 'Notification Token',
          body:
              "Your device's Firebase Cloud Messaging (FCM) token, used to send push notifications.",
        ),
        _BulletPoint(
          title: 'Device & Technical Data',
          body: 'Device model, OS version, app version, and crash logs.',
        ),
        SizedBox(height: 24),
        _Heading('2. How We Use Location'),
        _NumberedPoint(
          number: '1.',
          text:
              "A client's job location is shared with nearby workers for bid evaluation.",
        ),
        _NumberedPoint(
          number: '2.',
          text:
              "A worker's live location is shared with the client during an active job, for arrival tracking.",
        ),
        _NumberedPoint(
          number: '3.',
          text: 'Location sharing ends once the job session concludes.',
        ),
        _NumberedPoint(
          number: '4.',
          text:
              'We do not track location in the background beyond service delivery.',
        ),
        SizedBox(height: 24),
        _Heading('3. Camera, Microphone & Media Access'),
        _BodyText('The app may request the following device permissions:'),
        SizedBox(height: 8),
        _BulletPoint(
          title: 'Camera',
          body: 'To capture job-site photos or videos for postings or chat.',
        ),
        _BulletPoint(
          title: 'Microphone',
          body: 'To record voice notes for in-app chat.',
        ),
        _BulletPoint(
          title: 'Media Storage',
          body: 'To upload photos or videos from your device gallery.',
        ),
        SizedBox(height: 8),
        _BodyText(
          'These permissions operate only when you actively choose to '
          'share media; we do not access them in the background.',
        ),
        SizedBox(height: 24),
        _Heading('4. Notifications'),
        _BodyText('Push notifications tell you about platform activity:'),
        SizedBox(height: 8),
        _NumberedPoint(
          number: '1.',
          text: 'Booking confirmations and updates.',
        ),
        _NumberedPoint(
          number: '2.',
          text: 'New messages from clients or workers.',
        ),
        _NumberedPoint(number: '3.', text: 'New bids or bid updates.'),
        _NumberedPoint(
          number: '4.',
          text: 'Job status changes (en route, in progress, completed).',
        ),
        SizedBox(height: 8),
        _BodyText(
          'You can disable notifications through your device settings, '
          'though this may affect how well the service works for you.',
        ),
        SizedBox(height: 24),
        _Heading('5. How We Share Your Information'),
        _BodyText(
          'We do not sell your personal data. Information is shared only '
          'as necessary:',
        ),
        SizedBox(height: 8),
        _BulletPoint(
          title: 'Between Clients & Workers',
          body: 'When a job is bid on or assigned.',
        ),
        _BulletPoint(
          title: 'Service Providers',
          body:
              'For hosting, cloud storage, push notifications, and infrastructure.',
        ),
        _BulletPoint(
          title: 'Legal Requirements',
          body:
              'When required by law, court order, or to protect rights and safety.',
        ),
        SizedBox(height: 24),
        _Heading('6. Data Security'),
        _BulletPoint(
          title: 'Encryption',
          body: 'Data in transit is encrypted using HTTPS/TLS where supported.',
        ),
        _BulletPoint(
          title: 'Access Control',
          body: 'Restricted to authorized personnel and systems.',
        ),
        _BulletPoint(
          title: 'Monitoring',
          body:
              'Our production environment runs with standard controls and monitoring.',
        ),
        SizedBox(height: 8),
        _BodyText(
          'No system is 100% secure. If you suspect unauthorized use of '
          'your account, contact support@handygo.ai.',
        ),
        SizedBox(height: 24),
        _Heading('7. Account Deletion & Data Retention'),
        _BodyText('You may delete your account and its data at any time:'),
        SizedBox(height: 8),
        _BulletPoint(
          title: 'In-app',
          body: 'Profile → Settings → Danger Zone → Delete Account.',
        ),
        _BulletPoint(
          title: 'By email',
          body:
              'Write to support@handygo.ai with the subject "Handygo Account Deletion Request," including your phone number and role.',
        ),
        SizedBox(height: 8),
        _BodyText(
          'Once deleted, account access is disabled, notification tokens '
          'are cleared, and active sessions are removed. Jobs, bookings, '
          'messages, and reviews may be retained for safety, fraud '
          'prevention, dispute resolution, legal compliance, or service '
          'history purposes. Deletion requests are typically processed '
          'within 7–30 days.',
        ),
        SizedBox(height: 24),
        _Heading("8. Children's Privacy"),
        _BodyText(
          'Handygo is not intended for individuals under 18. We do not '
          'knowingly collect personal information from minors. If you '
          'believe a minor\'s data has been collected, contact '
          'support@handygo.ai for prompt deletion.',
        ),
        SizedBox(height: 24),
        _Heading('9. Changes to This Policy'),
        _BodyText(
          'We may update this Privacy Policy from time to time; the '
          'effective date at the top reflects the latest changes. '
          'Continued use of the app after an update constitutes your '
          'acceptance of it. We encourage you to review this policy '
          'periodically.',
        ),
        SizedBox(height: 24),
        _Heading('10. Contact Us'),
        _BodyText('Handygo Support — support@handygo.ai — handygo.ai'),
        SizedBox(height: 4),
        _BodyText('© 2026 Handygo. All rights reserved.'),
      ],
    );
  }
}

// ── Reusable text components ──────────────────────────────────────────────────

class _LastUpdated extends StatelessWidget {
  final String date;

  const _LastUpdated({required this.date});

  @override
  Widget build(BuildContext context) {
    return Text(
      'Last updated: $date',
      style: TextStyle(
        fontSize: 12.5,
        color: context.semanticColors.textSecondary,
        fontStyle: FontStyle.italic,
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  final String text;

  const _Heading(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          height: 1.35,
          color: context.semanticColors.textPrimary,
        ),
      ),
    );
  }
}

class _BodyText extends StatelessWidget {
  final String text;

  const _BodyText(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 14,
        height: 1.6,
        color: context.semanticColors.textSecondary,
      ),
    );
  }
}

class _BulletPoint extends StatelessWidget {
  final String title;
  final String body;

  const _BulletPoint({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 7),
            child: Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                color: c.primary,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(
                style: TextStyle(
                  fontSize: 14,
                  height: 1.6,
                  color: c.textSecondary,
                ),
                children: [
                  TextSpan(
                    text: '$title: ',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: c.textPrimary,
                    ),
                  ),
                  TextSpan(text: body),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NumberedPoint extends StatelessWidget {
  final String number;
  final String text;

  const _NumberedPoint({required this.number, required this.text});

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            number,
            style: TextStyle(
              fontSize: 14,
              height: 1.6,
              fontWeight: FontWeight.w700,
              color: c.primary,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                height: 1.6,
                color: c.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── L10N-LEGAL-BODY:END ──────────────────────────────────────────────────────
