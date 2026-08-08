/// The Customer Terms, Booking Rules aur Privacy Notice — the one legal
/// document every CLIENT must accept once per version before using the app.
///
/// Unlike the Ustaad flow, no "viewed at" evidence is required: the Client
/// only needs the opportunity to read/scroll/download before ticking the
/// checkbox, never a technical forcing of opening a separate viewer first.
library;

const String kCustomerTermsDocumentType =
    'CUSTOMER_TERMS_BOOKING_RULES_PRIVACY_NOTICE';
const String kCustomerTermsAgreementKey = 'customer-terms';

/// The approved document as returned by `GET /customer/agreements/required`.
class CustomerAgreementEntity {
  /// Stable backend code — never a translated label.
  final String documentType;
  final String title;
  final String version;

  /// The language of the LEGAL BODY, which is not necessarily the app's
  /// language. Currently always `ur_Latn`.
  final String agreementLocale;

  /// SHA-256 of the source text — informational only; never re-submitted by
  /// the client (the backend resolves it independently at accept time).
  final String sourceHash;
  final String contentText;

  /// True when the app language differs from [agreementLocale], so the
  /// screen must explain that the approved agreement is only available in
  /// Roman Urdu.
  final bool legalLanguageNoticeRequired;

  /// The app locale the request asked for, echoed back.
  final String requestedAppLocale;

  const CustomerAgreementEntity({
    required this.documentType,
    required this.title,
    required this.version,
    required this.agreementLocale,
    required this.sourceHash,
    required this.contentText,
    required this.legalLanguageNoticeRequired,
    required this.requestedAppLocale,
  });
}

/// Metadata for an already-sealed acceptance, echoed back inline by the
/// `required` endpoint so the gate can skip itself without a second call.
class CustomerAgreementAcceptanceSummaryEntity {
  final String id;
  final String? acceptanceId;
  final String version;
  final DateTime acceptedAt;

  const CustomerAgreementAcceptanceSummaryEntity({
    required this.id,
    required this.acceptanceId,
    required this.version,
    required this.acceptedAt,
  });
}

/// Whether the authenticated Client must accept Version 1.0 right now, plus
/// the document to show and (when already accepted) the existing record.
class CustomerAgreementStatusEntity {
  final bool acceptanceRequired;
  final CustomerAgreementEntity agreement;
  final CustomerAgreementAcceptanceSummaryEntity? existingAcceptance;

  const CustomerAgreementStatusEntity({
    required this.acceptanceRequired,
    required this.agreement,
    required this.existingAcceptance,
  });
}

/// One permanently sealed acceptance, as shown in the Client Profile's
/// "Accepted Agreements" history.
///
/// Immutable historical evidence: changing the app language later must never
/// alter [agreementLocale], [version] or [acceptedAt] on an existing record.
class AcceptedCustomerAgreementEntity {
  final String id;
  final String? acceptanceId;
  final String? documentType;
  final String title;
  final String version;
  final String agreementLocale;
  final DateTime acceptedAt;

  const AcceptedCustomerAgreementEntity({
    required this.id,
    required this.acceptanceId,
    required this.documentType,
    required this.title,
    required this.version,
    required this.agreementLocale,
    required this.acceptedAt,
  });

  /// What the secure download endpoint is addressed by.
  String get downloadId => acceptanceId ?? id;
}
