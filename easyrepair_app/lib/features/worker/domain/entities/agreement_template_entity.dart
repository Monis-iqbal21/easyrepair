/// The three documents an Ustaad must read and accept during profile
/// completion, and the evidence the backend demands back for each one.
///
/// The Customer document is deliberately absent from [kUstaadDocumentTypes].
/// Nothing in the Ustaad flow may derive its list of agreements from anywhere
/// else, so a Customer row can never appear on a worker screen.
library;

const String kUstaadGeneralAgreement = 'USTAAD_SERVICE_PROVIDER_AGREEMENT';
const String kUstaadTradeAgreement = 'TRADE_SPECIFIC_SERVICE_AGREEMENT';
const String kUstaadBackgroundEvsNotice =
    'BACKGROUND_VERIFICATION_EVS_PRIVACY_NOTICE';

/// Exactly three, in the order the profile-completion form shows them.
const List<String> kUstaadDocumentTypes = [
  kUstaadGeneralAgreement,
  kUstaadTradeAgreement,
  kUstaadBackgroundEvsNotice,
];

/// One approved agreement, as returned by
/// `GET /workers/profile-completion/agreement-templates`.
///
/// [contentText] is the backend-approved legal body. It is rendered verbatim
/// and is never reconstructed from, or translated by, app localization.
class AgreementTemplateEntity {
  /// Stable backend code — never a translated label.
  final String documentType;
  final String title;
  final String version;

  /// The language of the LEGAL BODY, which is not necessarily the app's
  /// language. Currently always `ur_Latn`.
  final String agreementLocale;

  /// SHA-256 of the source text. Submitted back as evidence so the backend can
  /// prove the Ustaad accepted the document it actually served.
  final String sourceHash;

  /// Only the trade document carries one.
  final String? applicableTrade;
  final String contentText;

  /// True when the app language differs from [agreementLocale], so the screen
  /// must explain that the approved agreement is only available in Roman Urdu.
  final bool legalLanguageNoticeRequired;

  /// The app locale the request asked for, echoed back.
  final String requestedAppLocale;

  const AgreementTemplateEntity({
    required this.documentType,
    required this.title,
    required this.version,
    required this.agreementLocale,
    required this.sourceHash,
    required this.applicableTrade,
    required this.contentText,
    required this.legalLanguageNoticeRequired,
    required this.requestedAppLocale,
  });

  bool get isGeneral => documentType == kUstaadGeneralAgreement;
  bool get isTrade => documentType == kUstaadTradeAgreement;
  bool get isBackgroundEvs => documentType == kUstaadBackgroundEvsNotice;

  /// Records that THIS exact document was opened and rendered at [viewedAt].
  AgreementEvidence evidenceViewedAt(DateTime viewedAt) => AgreementEvidence(
        documentType: documentType,
        version: version,
        sourceHash: sourceHash,
        agreementLocale: agreementLocale,
        applicableTrade: applicableTrade,
        viewedAt: viewedAt,
        checkboxAccepted: false,
      );
}

/// Proof that one specific document was viewed, and then accepted.
///
/// Carries the identity of the document only. Who the Ustaad is, when the
/// acceptance happened and every hash on the sealed record are resolved by the
/// backend — a value sent here for any of those would be ignored.
class AgreementEvidence {
  final String documentType;
  final String version;
  final String sourceHash;
  final String agreementLocale;
  final String? applicableTrade;

  /// When the viewer finished loading this exact document. A page that opened
  /// and failed to load never produces one.
  final DateTime viewedAt;
  final bool checkboxAccepted;

  const AgreementEvidence({
    required this.documentType,
    required this.version,
    required this.sourceHash,
    required this.agreementLocale,
    required this.applicableTrade,
    required this.viewedAt,
    required this.checkboxAccepted,
  });

  AgreementEvidence copyWith({bool? checkboxAccepted}) => AgreementEvidence(
        documentType: documentType,
        version: version,
        sourceHash: sourceHash,
        agreementLocale: agreementLocale,
        applicableTrade: applicableTrade,
        viewedAt: viewedAt,
        checkboxAccepted: checkboxAccepted ?? this.checkboxAccepted,
      );

  /// Whether this evidence still describes [template].
  ///
  /// A version, hash, language or trade change makes it stale: the Ustaad read
  /// a document that is no longer the active one, so the view must be repeated
  /// rather than the old tick carried forward.
  bool matches(AgreementTemplateEntity template) =>
      documentType == template.documentType &&
      version == template.version &&
      sourceHash == template.sourceHash &&
      agreementLocale == template.agreementLocale &&
      applicableTrade == template.applicableTrade;

  Map<String, dynamic> toJson() => {
        'documentType': documentType,
        'version': version,
        'sourceHash': sourceHash,
        'agreementLocale': agreementLocale,
        'applicableTrade': applicableTrade,
        'viewedAt': viewedAt.toUtc().toIso8601String(),
        'checkboxAccepted': checkboxAccepted,
      };
}

/// One permanently sealed acceptance, as shown in the Worker Legal section.
///
/// Immutable historical evidence: changing the app language later must never
/// alter [agreementLocale], [version] or [acceptedAt] on an existing record.
class AcceptedAgreementEntity {
  final String id;
  final String? acceptanceId;
  final String? documentType;
  final String title;
  final String version;
  final String agreementLocale;
  final String? applicableTrade;
  final DateTime acceptedAt;
  final DateTime? viewedAt;

  const AcceptedAgreementEntity({
    required this.id,
    required this.acceptanceId,
    required this.documentType,
    required this.title,
    required this.version,
    required this.agreementLocale,
    required this.applicableTrade,
    required this.acceptedAt,
    this.viewedAt,
  });

  /// What the secure download endpoint is addressed by.
  String get downloadId => acceptanceId ?? id;
}
