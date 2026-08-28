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

  /// A resend was attempted before the backend's 60-second cooldown elapsed.
  otpResendTooSoon,

  /// The CODE ITSELF was rejected — wrong, expired, or too many wrong
  /// guesses. Distinct from every other way an OTP screen's submit can fail
  /// (a network drop, an already-registered number, a server error), because
  /// only this one means the digits on screen are the problem: it is what
  /// tells an OTP field to mark itself, and what tells it not to.
  otpRejected,

  /// Rehire attempted while the original inspecting Ustaad is on another job.
  inspectorBusy,

  /// Login: the phone either doesn't exist at all or belongs to the
  /// opposite role. Deliberately the same code/message for both cases —
  /// see PhoneNotRegisteredFailure.
  phoneNotRegistered,

  /// Registration: the phone already has an account, regardless of role.
  phoneAlreadyRegistered,

  /// A server-changing action (create/cancel booking, send message, accept
  /// job, submit review, …) was attempted while the device has no network —
  /// blocked client-side before ever reaching the backend. Deliberately
  /// distinct from [noInternet]: that code means "a request was attempted
  /// and failed"; this one means "the app refused to even try", which reads
  /// differently to the user (see failure_messages.dart).
  offlineActionBlocked,

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

/// Login rejected because the phone either doesn't exist at all or belongs
/// to the opposite role (Client entering a Worker-owned number, or vice
/// versa). Both cases render identically — this app never reveals which one
/// actually happened, and never suggests "use the other login" (see the
/// role-privacy requirement this failure exists for).
class PhoneNotRegisteredFailure extends Failure {
  const PhoneNotRegisteredFailure(
    super.message, {
    super.code = FailureCode.phoneNotRegistered,
    super.diagnostic,
  });
}

/// Registration rejected because the phone already has an account —
/// regardless of which role owns it (User.phone is globally unique).
class PhoneAlreadyRegisteredFailure extends Failure {
  const PhoneAlreadyRegisteredFailure(
    super.message, {
    super.code = FailureCode.phoneAlreadyRegistered,
    super.diagnostic,
  });
}

/// The one-time code was rejected: `OTP_INVALID`, `OTP_EXPIRED` or
/// `OTP_ATTEMPTS_EXCEEDED`.
///
/// The backend writes a specific sentence for all three, so this carries no
/// wording of its own — it exists so a screen can tell "the digits are wrong"
/// apart from every other reason a submit failed, and mark the code field for
/// this case only.
class OtpRejectedFailure extends Failure {
  const OtpRejectedFailure(
    super.message, {
    super.code = FailureCode.otpRejected,
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

/// A resend was rejected because the backend's 60-second cooldown from the
/// previous request hasn't elapsed yet. [retryAfterSeconds], when the
/// backend includes it, is how many seconds remain — used to resume the
/// countdown UI instead of leaving the user stuck on a generic error (see
/// `expiresAtFromRetryAfter` in `otp_input_section.dart`).
class OtpResendTooSoonFailure extends Failure {
  final int? retryAfterSeconds;

  const OtpResendTooSoonFailure(
    super.message, {
    this.retryAfterSeconds,
    super.code = FailureCode.otpResendTooSoon,
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

/// A write action's notifier refused to even attempt the request because
/// [isDeviceOnline] reported no connectivity. See [FailureCode.offlineActionBlocked].
class OfflineActionBlockedFailure extends Failure {
  const OfflineActionBlockedFailure()
      : super('', code: FailureCode.offlineActionBlocked);
}
