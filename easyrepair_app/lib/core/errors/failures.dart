/// What went wrong, as a value the app owns.
///
/// A [Failure] crosses layer boundaries, so it must not carry language with
/// it: the data layer knows *which* failure happened, and only the widget tree
/// knows which language to say it in. `lib/core/errors/failure_messages.dart`
/// turns a code into text through `AppLocalizations`.
enum FailureCode {
  /// The request never reached the server (no connectivity, DNS, socket).
  noInternet,

  /// The connection was made but timed out.
  timeout,

  /// The caller cancelled the request; usually nothing to show.
  requestCancelled,

  /// 400 — the request itself was rejected.
  invalidRequest,

  /// 401 — the session is gone and the user has to log in again.
  unauthorized,

  /// 403 — authenticated, but not allowed to do this.
  forbidden,

  /// 404 — the resource is not there.
  notFound,

  /// 409 — the resource moved on (already accepted, already cancelled…).
  conflict,

  /// 429 — rate limited.
  tooManyRequests,

  /// 5xx.
  server,

  /// The backend's SMS provider could not deliver the OTP.
  smsSendFailed,

  /// Rehire attempted while the original inspecting Ustaad is on another job.
  inspectorBusy,

  /// The phone number already belongs to an Ustaad account.
  phoneIsWorker,

  /// The phone number already belongs to a Client account.
  phoneIsClient,

  /// Anything else. The screen's own fallback wording wins for this one.
  unknown,
}

abstract class Failure {
  /// Human-written free text, almost always authored by the backend.
  ///
  /// Shown to the user verbatim when it is not empty — this app does not own
  /// the wording and must never machine-translate it. Empty means "no human
  /// text": the UI renders [code] through `AppLocalizations` instead.
  final String message;

  /// The app-owned identity of this failure. See [FailureCode].
  final FailureCode code;

  /// Technical detail (a Dio message, an exception string) kept for logs and
  /// debugging. Never rendered in the interface, never translated.
  final String? diagnostic;

  const Failure(
    this.message, {
    this.code = FailureCode.unknown,
    this.diagnostic,
  });

  @override
  // l10n-ignore: Debug toString(), read in logs and never rendered in the UI
  String toString() => message.isNotEmpty ? message : '$runtimeType($code)';
}

class ServerFailure extends Failure {
  const ServerFailure(
    super.message, {
    super.code = FailureCode.server,
    super.diagnostic,
  });
}

class NetworkFailure extends Failure {
  const NetworkFailure(
    super.message, {
    super.code = FailureCode.noInternet,
    super.diagnostic,
  });
}

class UnauthorizedFailure extends Failure {
  const UnauthorizedFailure(
    super.message, {
    super.code = FailureCode.unauthorized,
    super.diagnostic,
  });
}

/// 403 — the account is authenticated but not permitted to do this.
class ForbiddenFailure extends Failure {
  const ForbiddenFailure(
    super.message, {
    super.code = FailureCode.forbidden,
    super.diagnostic,
  });
}

/// 404 — the booking, bid or profile being asked for no longer exists.
class NotFoundFailure extends Failure {
  const NotFoundFailure(
    super.message, {
    super.code = FailureCode.notFound,
    super.diagnostic,
  });
}

class ConflictFailure extends Failure {
  const ConflictFailure(
    super.message, {
    super.code = FailureCode.conflict,
    super.diagnostic,
  });
}

class ValidationFailure extends Failure {
  const ValidationFailure(
    super.message, {
    super.code = FailureCode.invalidRequest,
    super.diagnostic,
  });
}

/// The phone entered on the Client OTP login/register page already belongs
/// to a WORKER account — the Client page shows a distinct "Ustaad Login"
/// button instead of a plain error snackbar for this case.
class WorkerPhoneConflictFailure extends Failure {
  const WorkerPhoneConflictFailure(
    super.message, {
    super.code = FailureCode.phoneIsWorker,
    super.diagnostic,
  });
}

/// The phone entered on the Worker OTP registration page already belongs to
/// a CLIENT account.
class ClientPhoneConflictFailure extends Failure {
  const ClientPhoneConflictFailure(
    super.message, {
    super.code = FailureCode.phoneIsClient,
    super.diagnostic,
  });
}

/// The backend's SMS provider (VeevoTech) genuinely failed to send an OTP
/// (e.g. LOW_BALANCE) — pages must show a specific "try password instead"
/// message rather than a generic error, and must never expose the
/// provider's own response/details.
class SmsSendFailure extends Failure {
  const SmsSendFailure(
    super.message, {
    super.code = FailureCode.smsSendFailed,
    super.diagnostic,
  });
}

/// "Dobara Hire Karein" was tapped but the original inspecting Ustaad is
/// currently busy on another active job (backend error code INSPECTOR_BUSY).
/// The bidding page shows the specific message and MUST stay on the bidding
/// list with all other bids intact — never navigate away or clear loaded
/// state for this failure.
class InspectorBusyFailure extends Failure {
  const InspectorBusyFailure(
    super.message, {
    super.code = FailureCode.inspectorBusy,
    super.diagnostic,
  });
}
