import '../../domain/entities/user_entity.dart';

class UserModel {
  final String id;
  final String phone;
  final String role;
  final String firstName;
  final String lastName;
  final String? verificationStatus;
  final String? workerStatus;
  final String accountStatus;

  const UserModel({
    required this.id,
    required this.phone,
    required this.role,
    required this.firstName,
    required this.lastName,
    this.verificationStatus,
    this.workerStatus,
    this.accountStatus = 'ACTIVE',
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      phone: json['phone'] as String,
      role: json['role'] as String,
      firstName: json['firstName'] as String,
      lastName: json['lastName'] as String,
      verificationStatus: json['verificationStatus'] as String?,
      workerStatus: json['workerStatus'] as String?,
      // Defaults to 'ACTIVE' so a cached response from before this field
      // existed (or any backend that omits it) never gets misread as
      // restricted.
      accountStatus: json['accountStatus'] as String? ?? 'ACTIVE',
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
      workerStatus: workerStatus,
      accountStatus: accountStatus,
    );
  }
}
