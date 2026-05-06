class CategoryEntity {
  final String id;
  final String name;
  final String? iconUrl;

  const CategoryEntity({
    required this.id,
    required this.name,
    this.iconUrl,
  });
}
