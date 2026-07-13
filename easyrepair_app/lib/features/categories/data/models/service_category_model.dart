import '../../domain/entities/service_category_entity.dart';

class ServiceCategoryModel {
  final String id;
  final String name;
  final String? description;
  final String? iconUrl;
  final double? inspectionFee;

  const ServiceCategoryModel({
    required this.id,
    required this.name,
    this.description,
    this.iconUrl,
    this.inspectionFee,
  });

  factory ServiceCategoryModel.fromJson(Map<String, dynamic> json) {
    return ServiceCategoryModel(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      iconUrl: json['iconUrl'] as String?,
      inspectionFee: (json['inspectionFee'] as num?)?.toDouble(),
    );
  }

  ServiceCategoryEntity toEntity() => ServiceCategoryEntity(
        id: id,
        name: name,
        description: description,
        iconUrl: iconUrl,
        inspectionFee: inspectionFee,
      );
}
