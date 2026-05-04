import 'package:flutter/material.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              size: 18, color: Color(0xFF1A1A1A)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Privacy Policy',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1A1A1A),
          ),
        ),
        centerTitle: true,
      ),
      body: const SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: _PolicyContent(),
      ),
    );
  }
}

class _PolicyContent extends StatelessWidget {
  const _PolicyContent();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        _LastUpdated(date: 'April 2025'),
        SizedBox(height: 20),
        _BodyText(
          'EasyRepair ("we", "our", or "us") is committed to protecting your '
          'privacy. This Privacy Policy explains how we collect, use, store, '
          'and protect your personal information when you use the EasyRepair '
          'mobile application.',
        ),
        SizedBox(height: 24),
        _Heading('1. Information We Collect'),
        _BodyText(
          'We collect the following types of information to provide and improve our services:',
        ),
        SizedBox(height: 8),
        _BulletPoint(
          title: 'Account Information',
          body:
              'When you register, we collect your full name, phone number, and password. Workers may also provide professional credentials for identity verification.',
        ),
        _BulletPoint(
          title: 'Booking & Job Details',
          body:
              'We collect information about the services you request or provide, including job descriptions, dates, addresses, and status updates.',
        ),
        _BulletPoint(
          title: 'Chat & Media',
          body:
              'Messages, images, voice notes, and video clips exchanged through our in-app chat are stored to facilitate communication between clients and workers.',
        ),
        _BulletPoint(
          title: 'Location Data',
          body:
              'With your permission, we collect your device location to match you with nearby workers and to track job progress. Location data is used only while the app is active and is not shared with third parties beyond the service-matching process.',
        ),
        _BulletPoint(
          title: 'Attachments',
          body:
              'Files you attach to bookings or chat conversations (photos, videos, documents) are uploaded to secure cloud storage and retained for the duration of your booking history.',
        ),
        SizedBox(height: 24),
        _Heading('2. How We Use Your Information'),
        _BodyText(
          'We use the information we collect to:',
        ),
        SizedBox(height: 8),
        _NumberedPoint(
            number: '1.', text: 'Create and manage your account.'),
        _NumberedPoint(
            number: '2.',
            text:
                'Match clients with suitable workers based on location and service category.'),
        _NumberedPoint(
            number: '3.',
            text:
                'Facilitate bookings, job tracking, and in-app communication.'),
        _NumberedPoint(
            number: '4.',
            text: 'Send push notifications about job updates and messages.'),
        _NumberedPoint(
            number: '5.',
            text: 'Improve the reliability and performance of the platform.'),
        _NumberedPoint(
            number: '6.',
            text:
                'Comply with legal obligations and enforce our Terms of Service.'),
        SizedBox(height: 24),
        _Heading('3. Push Notifications'),
        _BodyText(
          'We use Firebase Cloud Messaging (FCM) to send you notifications regarding job requests, booking status changes, new messages, and platform updates. You can manage notification preferences through your device settings.',
        ),
        SizedBox(height: 24),
        _Heading('4. Data Storage & Security'),
        _BodyText(
          'Your data is stored on secure cloud servers. Access tokens are '
          'stored in encrypted storage on your device. Attachments and media '
          'are stored using S3-compatible cloud storage with access controls. '
          'We implement industry-standard security practices, including '
          'encrypted transmission (HTTPS/TLS) for all API communication.',
        ),
        SizedBox(height: 24),
        _Heading('5. Data Sharing'),
        _BodyText(
          'We do not sell your personal information to third parties. Your '
          'information may be shared only in the following limited cases:',
        ),
        SizedBox(height: 8),
        _BulletPoint(
          title: 'With Workers',
          body:
              'Clients\' name, location (for the booking), and job details are shared with the assigned worker to fulfil the service.',
        ),
        _BulletPoint(
          title: 'With Clients',
          body:
              'Workers\' name and professional profile are shared with clients who request a service.',
        ),
        _BulletPoint(
          title: 'Service Providers',
          body:
              'We use trusted third-party services (e.g., Firebase, cloud storage) that may process your data on our behalf under strict confidentiality agreements.',
        ),
        _BulletPoint(
          title: 'Legal Requirements',
          body:
              'We may disclose your information if required to do so by law or in response to a valid legal process.',
        ),
        SizedBox(height: 24),
        _Heading('6. Data Retention'),
        _BodyText(
          'We retain your account data for as long as your account is active. '
          'Booking records and chat histories are retained for service quality '
          'and dispute resolution purposes. You may request deletion of your '
          'account and associated data by contacting our support team.',
        ),
        SizedBox(height: 24),
        _Heading('7. Your Rights'),
        _BodyText(
          'You have the right to access, correct, or request deletion of your '
          'personal data. To exercise any of these rights, please contact us '
          'through the in-app support channel or at our official support email.',
        ),
        SizedBox(height: 24),
        _Heading('8. Changes to This Policy'),
        _BodyText(
          'We may update this Privacy Policy from time to time. When we do, '
          'we will notify you through the app. Continued use of the app after '
          'changes are published constitutes your acceptance of the updated policy.',
        ),
        SizedBox(height: 24),
        _Heading('9. Contact Us'),
        _BodyText(
          'If you have questions about this Privacy Policy or how we handle '
          'your data, please contact our support team through the EasyRepair app.',
        ),
        SizedBox(height: 40),
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
      style: const TextStyle(
        fontSize: 12,
        color: Color(0xFF6B7280),
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
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: Color(0xFF1A1A1A),
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
      style: const TextStyle(
        fontSize: 14,
        height: 1.6,
        color: Color(0xFF374151),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, left: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: CircleAvatar(
              radius: 3,
              backgroundColor: Color(0xFF1D9E75),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.6,
                  color: Color(0xFF374151),
                ),
                children: [
                  TextSpan(
                    text: '$title: ',
                    style: const TextStyle(fontWeight: FontWeight.w600),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            number,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1D9E75),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 14,
                height: 1.6,
                color: Color(0xFF374151),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
