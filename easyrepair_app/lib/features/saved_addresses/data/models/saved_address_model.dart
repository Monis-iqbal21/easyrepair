import '../../domain/entities/saved_address_entity.dart';

class SavedAddressModel {
  final String id;
  final String label;
  final String normalizedLabel;
  final String addressLine;
  final String city;
  final double latitude;
  final double longitude;

  const SavedAddressModel({
    required this.id,
    required this.label,
    required this.normalizedLabel,
    required this.addressLine,
    required this.city,
    required this.latitude,
    required this.longitude,
  });

  factory SavedAddressModel.fromJson(Map<String, dynamic> json) {
    return SavedAddressModel(
      id: json['id'] as String,
      label: json['label'] as String,
      normalizedLabel: json['normalizedLabel'] as String,
      addressLine: json['addressLine'] as String,
      city: json['city'] as String? ?? '',
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
    );
  }

  SavedAddressEntity toEntity() => SavedAddressEntity(
    id: id,
    label: label,
    normalizedLabel: normalizedLabel,
    addressLine: addressLine,
    city: city,
    latitude: latitude,
    longitude: longitude,
  );
}
