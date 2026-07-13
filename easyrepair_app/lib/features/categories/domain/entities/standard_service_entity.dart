/// A fixed-price catalog item offered under a service category (e.g. "AC
/// General Service — Rs 2100"). Fetched fresh from the backend for the
/// STANDARD booking lane — prices are never hardcoded client-side.
class StandardServiceEntity {
  final String id;
  final String categoryId;
  final String name;
  final String? description;
  final double price;
  final String? iconUrl;

  const StandardServiceEntity({
    required this.id,
    required this.categoryId,
    required this.name,
    this.description,
    required this.price,
    this.iconUrl,
  });
}
