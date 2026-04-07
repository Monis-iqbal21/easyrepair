import '../../domain/entities/user_entity.dart';

class UserModel {
  final String id;
  final String phone;
  final String role;
  final String firstName;
  final String lastName;
  final String? verificationStatus;

  const UserModel({
    required this.id,
    required this.phone,
    required this.role,
    required this.firstName,
    required this.lastName,
    this.verificationStatus,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      phone: json['phone'] as String,
      role: json['role'] as String,
      firstName: json['firstName'] as String,
      lastName: json['lastName'] as String,
      verificationStatus: json['verificationStatus'] as String?,
    );
  }

  UserEntity toEntity() {
    return UserEntity(
      id: id,
      phone: phone,
      role: role,
      firstName: firstName,
      lastName: lastName,
      verificationStatus: verificationStatus,
    );
  }
}
