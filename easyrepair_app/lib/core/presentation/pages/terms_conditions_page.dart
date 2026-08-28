import 'package:flutter/material.dart';

import '../../l10n/l10n_extensions.dart';
import '../../theme/app_semantic_colors.dart';
import '../widgets/legal_english_only_notice.dart';

/// The page chrome here (app bar, back button, the English-only notice) is
/// localized like the rest of the app. The document itself is not: the
/// approved Terms and Conditions text stays in English until professionally
/// translated Urdu and Roman Urdu versions are supplied. See
/// `docs/legal_translation_exclusions.md`.
///
/// SHARED SCREEN: reached from BOTH the Client and the Ustaad profile, and
/// presented identically to both. Only colour and type moved here — the
/// approved wording below is byte-for-byte what it was.
class TermsConditionsPage extends StatelessWidget {
  const TermsConditionsPage({super.key});

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
          context.l10n.settingsTermsConditions,
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
                  child: _TermsContent(),
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
// Everything below is the approved Terms and Conditions text. It is
// deliberately NOT localized and NOT machine-translated: legal wording needs a
// professionally approved Urdu / Roman Urdu translation before it can ship in
// another language. The hard-coded string audit reports this block as
// Category 5, not as missed migration work.
// See docs/legal_translation_exclusions.md.

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
  final String body;

  const _BulletPoint({required this.body});

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
            child: Text(
              body,
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
