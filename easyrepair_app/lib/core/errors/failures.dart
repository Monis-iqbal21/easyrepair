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

/// The backend's SMS provider (VeevoTech) genuinely failed to send an OTP
/// (e.g. LOW_BALANCE) — pages must show a specific "try password instead"
/// message rather than a generic error, and must never expose the
/// provider's own response/details.
class SmsSendFailure extends Failure {
  const SmsSendFailure(super.message);
}

/// "Dobara Hire Karein" was tapped but the original inspecting Ustaad is
/// currently busy on another active job (backend error code INSPECTOR_BUSY).
/// The bidding page shows the specific Roman Urdu message and MUST stay on
/// the bidding list with all other bids intact — never navigate away or
/// clear loaded state for this failure.
class InspectorBusyFailure extends Failure {
  const InspectorBusyFailure(super.message);
}
