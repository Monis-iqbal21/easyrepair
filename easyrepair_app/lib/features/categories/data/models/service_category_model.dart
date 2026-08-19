import '../../domain/entities/service_category_entity.dart';

class ServiceCategoryModel {
  final String id;
  final String name;
  final String? description;
  final String? iconUrl;
  final double? inspectionFee;
  final bool inspectionOnly;

  const ServiceCategoryModel({
    required this.id,
    required this.name,
    this.description,
    this.iconUrl,
    this.inspectionFee,
    this.inspectionOnly = false,
  });

  factory ServiceCategoryModel.fromJson(Map<String, dynamic> json) {
    return ServiceCategoryModel(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      iconUrl: json['iconUrl'] as String?,
      inspectionFee: (json['inspectionFee'] as num?)?.toDouble(),
      // Defaults false when absent so an older backend (or a cached payload
      // written before this field existed) keeps every lane, exactly as before.
      inspectionOnly: json['inspectionOnly'] as bool? ?? false,
    );
  }

  ServiceCategoryEntity toEntity() => ServiceCategoryEntity(
        id: id,
        name: name,
        description: description,
        iconUrl: iconUrl,
        inspectionFee: inspectionFee,
        inspectionOnly: inspectionOnly,
      );
}
