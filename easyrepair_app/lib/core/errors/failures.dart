abstract class Failure {
  final String message;
  const Failure(this.message);

  @override
  String toString() => message;
}

class ServerFailure extends Failure {
  const ServerFailure(super.message);
}

class NetworkFailure extends Failure {
  const NetworkFailure(super.message);
}

class UnauthorizedFailure extends Failure {
  const UnauthorizedFailure(super.message);
}

class ConflictFailure extends Failure {
  const ConflictFailure(super.message);
}

class ValidationFailure extends Failure {
  const ValidationFailure(super.message);
}

/// The phone entered on the Client OTP login/register page already belongs
/// to a WORKER account — the Client page shows a distinct "Ustaad Login"
/// button instead of a plain error snackbar for this case.
class WorkerPhoneConflictFailure extends Failure {
  const WorkerPhoneConflictFailure(super.message);
}

/// The phone entered on the Worker OTP registration page already belongs to
/// a CLIENT account.
class ClientPhoneConflictFailure extends Failure {
  const ClientPhoneConflictFailure(super.message);
}
