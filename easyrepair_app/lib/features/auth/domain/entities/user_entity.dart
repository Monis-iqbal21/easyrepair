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
  /// Values: 'ACTIVE' | 'SUSPENDED'. Present for every account (defaults to
  /// 'ACTIVE'); only meaningfully restrictive for CLIENT accounts today —
  /// completely separate from [workerStatus]. Drives the central Client-
  /// restriction routing gate — see `resolveClientRestrictedRedirect` in
  /// `core/router/app_router.dart`.
  final String accountStatus;

  const UserEntity({
    required this.id,
    required this.phone,
    required this.role,
    required this.firstName,
    required this.lastName,
    this.verificationStatus,
    this.workerStatus,
    this.accountStatus = 'ACTIVE',
  });

  bool get isWorker => role.toUpperCase() == 'WORKER';
  bool get isVerifiedWorker => isWorker && verificationStatus?.toUpperCase() == 'VERIFIED';
  /// Only SUSPENDED blocks the Worker app — ACTIVE and INACTIVE both behave
  /// normally (see CLAUDE.md / the suspension-lock requirement).
  bool get isSuspendedWorker => isWorker && workerStatus?.toUpperCase() == 'SUSPENDED';
  /// Only ever meaningful for CLIENT — a WORKER's accountStatus is never set
  /// to SUSPENDED by any current flow, but this stays role-gated defensively
  /// so a future accident on the backend can never lock out a Worker through
  /// the wrong mechanism.
  bool get isRestrictedClient => !isWorker && accountStatus.toUpperCase() == 'SUSPENDED';
}
