import '../../domain/entities/standard_service_entity.dart';

class StandardServiceModel {
  final String id;
  final String categoryId;
  final String name;
  final String? description;
  final double price;
  final String? iconUrl;

  const StandardServiceModel({
    required this.id,
    required this.categoryId,
    required this.name,
    this.description,
    required this.price,
    this.iconUrl,
  });

  factory StandardServiceModel.fromJson(Map<String, dynamic> json) {
    return StandardServiceModel(
      id: json['id'] as String,
      categoryId: json['categoryId'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      price: (json['price'] as num).toDouble(),
      iconUrl: json['iconUrl'] as String?,
    );
  }

  StandardServiceEntity toEntity() => StandardServiceEntity(
        id: id,
        categoryId: categoryId,
        name: name,
        description: description,
        price: price,
        iconUrl: iconUrl,
      );
}
