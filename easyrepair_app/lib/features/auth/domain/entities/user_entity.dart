class UserEntity {
  final String id;
  final String phone;
  final String role;
  final String firstName;
  final String lastName;
  /// Only present for WORKER accounts. Values: 'PENDING' | 'VERIFIED' | 'REJECTED'
  final String? verificationStatus;

  const UserEntity({
    required this.id,
    required this.phone,
    required this.role,
    required this.firstName,
    required this.lastName,
    this.verificationStatus,
  });

  bool get isWorker => role.toUpperCase() == 'WORKER';
  bool get isVerifiedWorker => isWorker && verificationStatus?.toUpperCase() == 'VERIFIED';
}
