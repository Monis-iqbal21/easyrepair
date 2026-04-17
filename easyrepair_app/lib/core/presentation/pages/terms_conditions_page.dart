import 'package:flutter/material.dart';

class TermsConditionsPage extends StatelessWidget {
  const TermsConditionsPage({super.key});

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
          'Terms & Conditions',
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
        child: _TermsContent(),
      ),
    );
  }
}

class _TermsContent extends StatelessWidget {
  const _TermsContent();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        _LastUpdated(date: 'April 2025'),
        SizedBox(height: 20),
        _BodyText(
          'Welcome to EasyRepair. By creating an account or using our '
          'application, you agree to these Terms and Conditions. Please read '
          'them carefully.',
        ),
        SizedBox(height: 24),
        _Heading('1. Service Marketplace'),
        _BodyText(
          'EasyRepair is an on-demand service marketplace that connects '
          'clients seeking home repair and maintenance services with '
          'independent service workers. EasyRepair acts as a technology '
          'platform only and is not itself a service provider. We do not '
          'employ workers directly. All service work is carried out '
          'independently by the registered workers on our platform.',
        ),
        SizedBox(height: 24),
        _Heading('2. User Eligibility'),
        _BodyText(
          'You must be at least 18 years of age to register and use EasyRepair. '
          'By creating an account, you confirm that the information you provide '
          'is accurate, current, and complete. You are responsible for '
          'maintaining the confidentiality of your account credentials.',
        ),
        SizedBox(height: 24),
        _Heading('3. Client Responsibilities'),
        _BulletPoint(
          body:
              'Provide accurate service descriptions and location details when creating a booking.',
        ),
        _BulletPoint(
          body:
              'Be available at the agreed location and time when a worker is dispatched.',
        ),
        _BulletPoint(
          body:
              'Treat workers with respect and professionalism. Abusive or threatening behaviour will result in account suspension.',
        ),
        _BulletPoint(
          body:
              'Ensure that media or attachments uploaded to the platform are relevant to the service request and do not violate any laws.',
        ),
        SizedBox(height: 24),
        _Heading('4. Worker Responsibilities'),
        _BulletPoint(
          body:
              'Provide truthful professional credentials during registration and verification.',
        ),
        _BulletPoint(
          body:
              'Accept or decline booking requests promptly within the allocated response window.',
        ),
        _BulletPoint(
          body:
              'Perform services diligently, professionally, and in accordance with applicable safety standards.',
        ),
        _BulletPoint(
          body:
              'Treat clients with respect and professionalism at all times.',
        ),
        _BulletPoint(
          body:
              'Keep your availability status accurate and update it promptly when unavailable.',
        ),
        SizedBox(height: 24),
        _Heading('5. Bookings & Cancellations'),
        _BodyText(
          'Clients may create bookings for available services. Workers may '
          'accept, reject, or let a booking request expire within the '
          'response window. Once accepted, a booking proceeds through the '
          'following stages: Accepted → En Route → In Progress → Completed.',
        ),
        SizedBox(height: 8),
        _BodyText(
          'Bookings may be cancelled by the client or, under certain '
          'conditions, by the worker, prior to the In Progress stage. '
          'EasyRepair reserves the right to apply cancellation policies '
          'to protect both parties in the event of repeated unreasonable '
          'cancellations.',
        ),
        SizedBox(height: 24),
        _Heading('6. Payments & Platform Fee'),
        _BodyText(
          'Pricing and payment terms for services are established between '
          'clients and workers, subject to platform policies. EasyRepair '
          'may collect a platform service fee on completed bookings. Details '
          'of applicable fees are disclosed within the booking flow. '
          'EasyRepair is not responsible for disputes arising from '
          'payment arrangements made outside of the platform.',
        ),
        SizedBox(height: 24),
        _Heading('7. Prohibited Conduct'),
        _BodyText(
          'The following actions are strictly prohibited on EasyRepair:',
        ),
        SizedBox(height: 8),
        _BulletPoint(
          body:
              'Creating fake or duplicate accounts.',
        ),
        _BulletPoint(
          body:
              'Submitting fraudulent or misleading service requests or reviews.',
        ),
        _BulletPoint(
          body:
              'Sharing contact information to conduct transactions outside the platform in order to avoid platform fees.',
        ),
        _BulletPoint(
          body:
              'Uploading illegal, offensive, or harmful content via chat or attachments.',
        ),
        _BulletPoint(
          body:
              'Harassing, threatening, or discriminating against any other user.',
        ),
        SizedBox(height: 24),
        _Heading('8. Account Suspension & Termination'),
        _BodyText(
          'EasyRepair reserves the right to suspend or permanently terminate '
          'any account that violates these Terms, engages in fraudulent '
          'activity, or poses a risk to other users or the platform. '
          'Users subject to termination will be notified where possible. '
          'EasyRepair is not liable for any loss resulting from account '
          'suspension or termination due to policy violations.',
        ),
        SizedBox(height: 24),
        _Heading('9. Limitation of Liability'),
        _BodyText(
          'EasyRepair provides the platform on an "as is" and "as available" '
          'basis. We make no warranties regarding the quality, safety, '
          'or fitness of the services provided by workers. EasyRepair is '
          'not liable for any direct, indirect, incidental, or consequential '
          'damages arising from the use of our platform, including damages '
          'resulting from service quality disputes, personal injury, or '
          'property damage.',
        ),
        SizedBox(height: 24),
        _Heading('10. Dispute Resolution'),
        _BodyText(
          'In the event of a dispute between a client and a worker, '
          'EasyRepair may, at its discretion, facilitate communication '
          'between the parties to help reach a resolution. EasyRepair is '
          'not obligated to arbitrate or resolve disputes and does not '
          'guarantee any particular outcome.',
        ),
        SizedBox(height: 24),
        _Heading('11. Changes to These Terms'),
        _BodyText(
          'EasyRepair may update these Terms and Conditions at any time. '
          'Users will be notified of material changes through the app. '
          'Continued use of EasyRepair after changes are published '
          'constitutes your acceptance of the updated terms.',
        ),
        SizedBox(height: 24),
        _Heading('12. Governing Law'),
        _BodyText(
          'These Terms are governed by the applicable laws of the '
          'jurisdiction in which EasyRepair operates. Any legal disputes '
          'arising from these Terms shall be subject to the exclusive '
          'jurisdiction of the courts in that jurisdiction.',
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
  final String body;

  const _BulletPoint({required this.body});

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
              backgroundColor: Color(0xFFDE7356),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              body,
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
