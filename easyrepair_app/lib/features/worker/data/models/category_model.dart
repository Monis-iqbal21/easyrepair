import '../../domain/entities/category_entity.dart';

class CategoryModel {
  final String id;
  final String name;
  final String? iconUrl;

  const CategoryModel({required this.id, required this.name, this.iconUrl});

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
      id: json['id'] as String,
      name: json['name'] as String,
      iconUrl: json['iconUrl'] as String?,
    );
  }

  CategoryEntity toEntity() {
    return CategoryEntity(id: id, name: name, iconUrl: iconUrl);
  }
}
