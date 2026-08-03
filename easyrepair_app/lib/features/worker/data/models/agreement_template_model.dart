import '../../domain/entities/agreement_template_entity.dart';

/// An agreement response did not carry a field the flow genuinely depends on.
///
/// Deliberately loud. The alternative — defaulting a missing `sourceHash` or
/// `version` to `''` — produces acceptance evidence that describes no real
/// document, which the backend then rejects as stale with nothing on screen
/// explaining why. A missing required field is a broken contract (most often a
/// backend that has not been redeployed), and it must surface as one.
class AgreementResponseFormatException implements Exception {
  /// Which payload was malformed, e.g. `agreement template`.
  final String resource;

  /// The JSON key that was absent or of the wrong type.
  final String field;

  const AgreementResponseFormatException(this.resource, this.field);

  @override
  // l10n-ignore: Developer diagnostic carried in Failure.diagnostic, never shown
  String toString() =>
      'Malformed $resource response: "$field" is missing or not a string. '
      'The API this build expects may not be deployed yet.';
}

/// A value the flow cannot proceed without.
String _required(Map<String, dynamic> json, String key, String resource) {
  final value = json[key];
  if (value is String && value.isNotEmpty) return value;
  throw AgreementResponseFormatException(resource, key);
}

/// A value that is legitimately absent for some documents — `applicableTrade`
/// is null on the General and EVS agreements, and `acceptanceId` is null on
/// older records. Anything non-string is treated as absent rather than cast.
String? _optional(Map<String, dynamic> json, String key) {
  final value = json[key];
  return value is String && value.isNotEmpty ? value : null;
}

DateTime _requiredDate(Map<String, dynamic> json, String key, String resource) {
  final parsed = _optionalDate(json, key);
  if (parsed == null) throw AgreementResponseFormatException(resource, key);
  return parsed;
}

DateTime? _optionalDate(Map<String, dynamic> json, String key) {
  final value = json[key];
  return value is String ? DateTime.tryParse(value) : null;
}

/// Wire shape of `GET /workers/profile-completion/agreement-templates`.
class AgreementTemplateModel {
  static const _resource = 'agreement template';

  final String documentType;
  final String title;
  final String version;
  final String agreementLocale;
  final String sourceHash;
  final String? applicableTrade;
  final String contentText;
  final bool legalLanguageNoticeRequired;
  final String requestedAppLocale;

  const AgreementTemplateModel({
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

  factory AgreementTemplateModel.fromJson(Map<String, dynamic> json) {
    // Required: every one of these is either shown to the Ustaad as the
    // document itself, or submitted back as the evidence that identifies it.
    //
    // Checked in payload order rather than inline, so the field a reader looks
    // for first is the one named first. `documentType` is exactly what a
    // pre-agreement backend omits — the legacy payload called it `type` and
    // carried no hash and no locale at all.
    final documentType = _required(json, 'documentType', _resource);
    final title = _required(json, 'title', _resource);
    final version = _required(json, 'version', _resource);
    final agreementLocale = _required(json, 'agreementLocale', _resource);
    final sourceHash = _required(json, 'sourceHash', _resource);
    final contentText = _required(json, 'contentText', _resource);

    return AgreementTemplateModel(
      documentType: documentType,
      title: title,
      version: version,
      agreementLocale: agreementLocale,
      sourceHash: sourceHash,
      contentText: contentText,
      // Null for the General and EVS documents by design.
      applicableTrade: _optional(json, 'applicableTrade'),
      // Presentation-only metadata: a safe default changes nothing legal.
      legalLanguageNoticeRequired:
          json['legalLanguageNoticeRequired'] as bool? ?? false,
      requestedAppLocale:
          _optional(json, 'requestedAppLocale') ?? agreementLocale,
    );
  }

  AgreementTemplateEntity toEntity() => AgreementTemplateEntity(
        documentType: documentType,
        title: title,
        version: version,
        agreementLocale: agreementLocale,
        sourceHash: sourceHash,
        applicableTrade: applicableTrade,
        contentText: contentText,
        legalLanguageNoticeRequired: legalLanguageNoticeRequired,
        requestedAppLocale: requestedAppLocale,
      );
}

/// Wire shape of `GET /workers/profile-completion/agreements` — the Ustaad's
/// own sealed acceptance records. Metadata only: the backend never returns a
/// storage URL, so there is nothing here to leak.
class AcceptedAgreementModel {
  static const _resource = 'accepted agreement';

  final String id;
  final String? acceptanceId;
  final String? documentType;
  final String title;
  final String version;
  final String agreementLocale;
  final String? applicableTrade;
  final DateTime acceptedAt;
  final DateTime? viewedAt;

  const AcceptedAgreementModel({
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

  factory AcceptedAgreementModel.fromJson(Map<String, dynamic> json) {
    return AcceptedAgreementModel(
      id: _required(json, 'id', _resource),
      title: _required(json, 'title', _resource),
      version: _required(json, 'version', _resource),
      agreementLocale: _required(json, 'agreementLocale', _resource),
      // A record with no acceptance date is not evidence of anything, so it is
      // never silently shown with a placeholder date.
      acceptedAt: _requiredDate(json, 'acceptedAt', _resource),
      // Genuinely optional: null on the General/EVS documents, on records
      // sealed before public acceptance ids existed, and before view tracking.
      acceptanceId: _optional(json, 'acceptanceId'),
      documentType: _optional(json, 'documentType'),
      applicableTrade: _optional(json, 'applicableTrade'),
      viewedAt: _optionalDate(json, 'viewedAt'),
    );
  }

  AcceptedAgreementEntity toEntity() => AcceptedAgreementEntity(
        id: id,
        acceptanceId: acceptanceId,
        documentType: documentType,
        title: title,
        version: version,
        agreementLocale: agreementLocale,
        applicableTrade: applicableTrade,
        acceptedAt: acceptedAt,
        viewedAt: viewedAt,
      );
}
