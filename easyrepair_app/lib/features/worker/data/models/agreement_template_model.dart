import '../../domain/entities/agreement_template_entity.dart';

/// Wire shape of `GET /workers/profile-completion/agreement-templates`.
class AgreementTemplateModel {
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
    return AgreementTemplateModel(
      documentType: json['documentType'] as String,
      title: json['title'] as String,
      version: json['version'] as String,
      agreementLocale: json['agreementLocale'] as String? ?? 'ur_Latn',
      sourceHash: json['sourceHash'] as String? ?? '',
      applicableTrade: json['applicableTrade'] as String?,
      contentText: json['contentText'] as String? ?? '',
      legalLanguageNoticeRequired:
          json['legalLanguageNoticeRequired'] as bool? ?? false,
      requestedAppLocale: json['requestedAppLocale'] as String? ?? 'ur_Latn',
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
      id: json['id'] as String,
      acceptanceId: json['acceptanceId'] as String?,
      documentType: json['documentType'] as String?,
      title: json['title'] as String? ?? '',
      version: json['version'] as String? ?? '',
      agreementLocale: json['agreementLocale'] as String? ?? 'ur_Latn',
      applicableTrade: json['applicableTrade'] as String?,
      acceptedAt:
          DateTime.tryParse(json['acceptedAt'] as String? ?? '') ??
              DateTime.fromMillisecondsSinceEpoch(0),
      viewedAt: json['viewedAt'] != null
          ? DateTime.tryParse(json['viewedAt'] as String)
          : null,
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
