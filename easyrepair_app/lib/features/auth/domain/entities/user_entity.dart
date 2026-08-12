class UserEntity {
  final String id;
  final String phone;
  final String role;
  final String firstName;
  final String lastName;
  /// Only present for WORKER accounts. Values: 'PENDING' | 'VERIFIED' | 'REJECTED'
  final String? verificationStatus;
  /// Only present for WORKER accounts. Values: 'ACTIVE' | 'INACTIVE' | 'SUSPENDED'.
  /// Drives the central Worker-suspension routing gate — see
  /// `resolveWorkerSuspendedRedirect` in `core/router/app_router.dart`.
  final String? workerStatus;

  const UserEntity({
    required this.id,
    required this.phone,
    required this.role,
    required this.firstName,
    required this.lastName,
    this.verificationStatus,
    this.workerStatus,
  });

  bool get isWorker => role.toUpperCase() == 'WORKER';
  bool get isVerifiedWorker => isWorker && verificationStatus?.toUpperCase() == 'VERIFIED';
  /// Only SUSPENDED blocks the Worker app — ACTIVE and INACTIVE both behave
  /// normally (see CLAUDE.md / the suspension-lock requirement).
  bool get isSuspendedWorker => isWorker && workerStatus?.toUpperCase() == 'SUSPENDED';
}
