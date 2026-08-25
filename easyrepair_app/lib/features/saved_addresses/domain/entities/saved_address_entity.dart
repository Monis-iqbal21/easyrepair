class SavedAddressEntity {
  final String id;
  final String label;
  final String normalizedLabel;
  final String addressLine;
  final String city;
  final double latitude;
  final double longitude;

  const SavedAddressEntity({
    required this.id,
    required this.label,
    required this.normalizedLabel,
    required this.addressLine,
    required this.city,
    required this.latitude,
    required this.longitude,
  });
}
