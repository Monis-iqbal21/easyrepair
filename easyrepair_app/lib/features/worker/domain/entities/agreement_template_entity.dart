class AgreementTemplateEntity {
  final String id;
  final String type;
  final String title;
  final String version;
  final String contentText;

  const AgreementTemplateEntity({
    required this.id,
    required this.type,
    required this.title,
    required this.version,
    required this.contentText,
  });

  bool get isGeneral => type == 'GENERAL_USTAAD';
  bool get isTrade => type == 'TRADE_SPECIFIC';
}
