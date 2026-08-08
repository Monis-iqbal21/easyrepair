import '../../domain/entities/customer_agreement_entity.dart';

/// A Customer agreement response did not carry a field the flow genuinely
/// depends on.
///
/// Deliberately loud — see the Worker-side
/// `AgreementResponseFormatException` this mirrors. A missing required field
/// means the backend this build expects may not be deployed yet, and it must
/// surface as that, not as a silently-broken gate.
class CustomerAgreementResponseFormatException implements Exception {
  final String resource;
  final String field;

  const CustomerAgreementResponseFormatException(this.resource, this.field);

  @override
  // l10n-ignore: Developer diagnostic carried in Failure.diagnostic, never shown
  String toString() =>
      'Malformed $resource response: "$field" is missing or not the '
      'expected type. The API this build expects may not be deployed yet.';
}

String _required(Map<String, dynamic> json, String key, String resource) {
  final value = json[key];
  if (value is String && value.isNotEmpty) return value;
  throw CustomerAgreementResponseFormatException(resource, key);
}

String? _optional(Map<String, dynamic> json, String key) {
  final value = json[key];
  return value is String && value.isNotEmpty ? value : null;
}

DateTime _requiredDate(Map<String, dynamic> json, String key, String resource) {
  final value = json[key];
  final parsed = value is String ? DateTime.tryParse(value) : null;
  if (parsed == null) throw CustomerAgreementResponseFormatException(resource, key);
  return parsed;
}

/// Wire shape of the `agreement` object inside
/// `GET /customer/agreements/required`.
class CustomerAgreementModel {
  static const _resource = 'customer agreement';

  final String documentType;
  final String title;
  final String version;
  final String agreementLocale;
  final String sourceHash;
  final String contentText;
  final bool legalLanguageNoticeRequired;
  final String requestedAppLocale;

  const CustomerAgreementModel({
    required this.documentType,
    required this.title,
    required this.version,
    required this.agreementLocale,
    required this.sourceHash,
    required this.contentText,
    required this.legalLanguageNoticeRequired,
    required this.requestedAppLocale,
  });

  factory CustomerAgreementModel.fromJson(Map<String, dynamic> json) {
    final documentType = _required(json, 'documentType', _resource);
    final title = _required(json, 'title', _resource);
    final version = _required(json, 'version', _resource);
    final agreementLocale = _required(json, 'agreementLocale', _resource);
    final sourceHash = _required(json, 'sourceHash', _resource);
    final contentText = _required(json, 'contentText', _resource);

    return CustomerAgreementModel(
      documentType: documentType,
      title: title,
      version: version,
      agreementLocale: agreementLocale,
      sourceHash: sourceHash,
      contentText: contentText,
      legalLanguageNoticeRequired:
          json['legalLanguageNoticeRequired'] as bool? ?? false,
      requestedAppLocale:
          _optional(json, 'requestedAppLocale') ?? agreementLocale,
    );
  }

  CustomerAgreementEntity toEntity() => CustomerAgreementEntity(
        documentType: documentType,
        title: title,
        version: version,
        agreementLocale: agreementLocale,
        sourceHash: sourceHash,
        contentText: contentText,
        legalLanguageNoticeRequired: legalLanguageNoticeRequired,
        requestedAppLocale: requestedAppLocale,
      );
}

class CustomerAgreementAcceptanceSummaryModel {
  static const _resource = 'agreement acceptance';

  final String id;
  final String? acceptanceId;
  final String version;
  final DateTime acceptedAt;

  const CustomerAgreementAcceptanceSummaryModel({
    required this.id,
    required this.acceptanceId,
    required this.version,
    required this.acceptedAt,
  });

  factory CustomerAgreementAcceptanceSummaryModel.fromJson(
    Map<String, dynamic> json,
  ) {
    return CustomerAgreementAcceptanceSummaryModel(
      id: _required(json, 'id', _resource),
      version: _required(json, 'version', _resource),
      acceptedAt: _requiredDate(json, 'acceptedAt', _resource),
      acceptanceId: _optional(json, 'acceptanceId'),
    );
  }

  CustomerAgreementAcceptanceSummaryEntity toEntity() =>
      CustomerAgreementAcceptanceSummaryEntity(
        id: id,
        acceptanceId: acceptanceId,
        version: version,
        acceptedAt: acceptedAt,
      );
}

/// Wire shape of `GET /customer/agreements/required`.
class CustomerAgreementStatusModel {
  final bool acceptanceRequired;
  final CustomerAgreementModel agreement;
  final CustomerAgreementAcceptanceSummaryModel? existingAcceptance;

  const CustomerAgreementStatusModel({
    required this.acceptanceRequired,
    required this.agreement,
    required this.existingAcceptance,
  });

  factory CustomerAgreementStatusModel.fromJson(Map<String, dynamic> json) {
    final agreementJson = json['agreement'];
    if (agreementJson is! Map<String, dynamic>) {
      throw const CustomerAgreementResponseFormatException(
        'customer agreement status',
        'agreement',
      );
    }
    final existingJson = json['existingAcceptance'];

    return CustomerAgreementStatusModel(
      acceptanceRequired: json['acceptanceRequired'] as bool? ?? true,
      agreement: CustomerAgreementModel.fromJson(agreementJson),
      existingAcceptance: existingJson is Map<String, dynamic>
          ? CustomerAgreementAcceptanceSummaryModel.fromJson(existingJson)
          : null,
    );
  }

  CustomerAgreementStatusEntity toEntity() => CustomerAgreementStatusEntity(
        acceptanceRequired: acceptanceRequired,
        agreement: agreement.toEntity(),
        existingAcceptance: existingAcceptance?.toEntity(),
      );
}

/// Wire shape of one row in `GET /customer/agreements/history`.
class AcceptedCustomerAgreementModel {
  static const _resource = 'accepted customer agreement';

  final String id;
  final String? acceptanceId;
  final String? documentType;
  final String title;
  final String version;
  final String agreementLocale;
  final DateTime acceptedAt;

  const AcceptedCustomerAgreementModel({
    required this.id,
    required this.acceptanceId,
    required this.documentType,
    required this.title,
    required this.version,
    required this.agreementLocale,
    required this.acceptedAt,
  });

  factory AcceptedCustomerAgreementModel.fromJson(Map<String, dynamic> json) {
    return AcceptedCustomerAgreementModel(
      id: _required(json, 'id', _resource),
      title: _required(json, 'title', _resource),
      version: _required(json, 'version', _resource),
      agreementLocale: _required(json, 'agreementLocale', _resource),
      acceptedAt: _requiredDate(json, 'acceptedAt', _resource),
      acceptanceId: _optional(json, 'acceptanceId'),
      documentType: _optional(json, 'documentType'),
    );
  }

  AcceptedCustomerAgreementEntity toEntity() =>
      AcceptedCustomerAgreementEntity(
        id: id,
        acceptanceId: acceptanceId,
        documentType: documentType,
        title: title,
        version: version,
        agreementLocale: agreementLocale,
        acceptedAt: acceptedAt,
      );
}
