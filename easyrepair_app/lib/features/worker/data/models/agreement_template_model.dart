import '../../domain/entities/agreement_template_entity.dart';

class AgreementTemplateModel {
  final String id;
  final String type;
  final String title;
  final String version;
  final String contentText;

  const AgreementTemplateModel({
    required this.id,
    required this.type,
    required this.title,
    required this.version,
    required this.contentText,
  });

  factory AgreementTemplateModel.fromJson(Map<String, dynamic> json) {
    return AgreementTemplateModel(
      id: json['id'] as String,
      type: json['type'] as String,
      title: json['title'] as String,
      version: json['version'] as String,
      contentText: json['contentText'] as String,
    );
  }

  AgreementTemplateEntity toEntity() {
    return AgreementTemplateEntity(
      id: id,
      type: type,
      title: title,
      version: version,
      contentText: contentText,
    );
  }
}
