import 'package:dio/dio.dart';
import 'failures.dart';

/// Turns a [DioException] into a [Failure].
///
/// This file is deliberately free of user-facing wording. It decides *what*
/// went wrong ([FailureCode]) and passes through any human sentence the
/// backend wrote; the language the user reads is chosen later, in
/// `failure_messages.dart`, from `AppLocalizations`.
///
/// [preserveUnauthorizedMessage] controls what happens to a 401's message:
///
///  * `false` (default) — the message is discarded and `failure_messages.dart`
///    renders the generic "session expired" copy instead. Correct for every
///    *protected* endpoint: a 401 there always means the access token is
///    missing/invalid/expired, and NestJS's own default rejection message
///    ("Unauthorized") is not something to show a user.
///  * `true` — the backend's actual sentence is kept ("Invalid phone number
///    or password", "Account is deactivated", …). Only pass this for a
///    public, pre-login auth call (login, register, OTP, password reset):
///    there a 401 means the *credentials* were rejected, not that a session
///    expired, and the backend already writes a message meant for the user.
Failure dioExceptionToFailure(
  DioException e, {
  bool preserveUnauthorizedMessage = false,
}) {
  switch (e.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
      return NetworkFailure(
        '',
        code: FailureCode.timeout,
        diagnostic: e.message,
      );

    case DioExceptionType.connectionError:
      return NetworkFailure(
        '',
        code: FailureCode.noInternet,
        diagnostic: e.message,
      );

    case DioExceptionType.badCertificate:
      return NetworkFailure(
        '',
        code: FailureCode.noInternet,
        diagnostic: e.message,
      );

    case DioExceptionType.badResponse:
      final statusCode = e.response?.statusCode;
      final data = e.response?.data;

      // `message` is only ever a sentence a human wrote on the backend. An
      // echo of the machine code is filtered out by _humanMessage.
      final message = _humanMessage(data);
      final errorCode = _extractErrorCode(data);
      final diagnostic = _diagnostic(statusCode, errorCode);

      if (errorCode == 'SMS_SEND_FAILED') {
        // A genuine VeevoTech provider failure (e.g. LOW_BALANCE) — never
        // show the raw provider/API details, just the code as a signal for
        // pages to render their own specific fallback message.
        return SmsSendFailure(message ?? '', diagnostic: diagnostic);
      }

      if (errorCode == 'OTP_RESEND_TOO_SOON') {
        // retryAfterSeconds lets the OTP page resume its countdown from the
        // backend's own cooldown clock rather than guessing — see
        // OtpRequestNotifier.request.
        return OtpResendTooSoonFailure(
          message ?? '',
          retryAfterSeconds: _extractRetryAfterSeconds(data),
          diagnostic: diagnostic,
        );
      }

      if (errorCode == 'OTP_INVALID' ||
          errorCode == 'OTP_EXPIRED' ||
          errorCode == 'OTP_ATTEMPTS_EXCEEDED') {
        // All three are 400s carrying the backend's own sentence, so the
        // message still passes straight through. The separate failure exists
        // so an OTP screen can mark its code field for these and ONLY these —
        // a timeout or an already-registered number is not the code's fault
        // and must not be drawn as if it were.
        return OtpRejectedFailure(message ?? '', diagnostic: diagnostic);
      }

      if (statusCode == 400) {
        return ValidationFailure(message ?? '', diagnostic: diagnostic);
      } else if (statusCode == 401) {
        if (errorCode == 'PHONE_NOT_REGISTERED') {
          // A public login endpoint rejecting a phone that either doesn't
          // exist or belongs to the opposite role. Always mapped to its own
          // FailureCode (never the generic "session expired" one) regardless
          // of [preserveUnauthorizedMessage] — the backend sends an empty
          // message for this code by design, so failure_messages.dart
          // renders it through AppLocalizations in the user's own language.
          return PhoneNotRegisteredFailure(message ?? '', diagnostic: diagnostic);
        }
        return UnauthorizedFailure(
          preserveUnauthorizedMessage ? (message ?? '') : '',
          diagnostic: diagnostic,
        );
      } else if (statusCode == 403) {
        return ForbiddenFailure(message ?? '', diagnostic: diagnostic);
      } else if (statusCode == 404) {
        return NotFoundFailure(message ?? '', diagnostic: diagnostic);
      } else if (statusCode == 409) {
        if (errorCode == 'INSPECTOR_BUSY') {
          // Rehire attempt while the original inspector is on another job —
          // the bidding page shows this exact message and keeps the bid list
          // open (see InspectorBusyFailure).
          return InspectorBusyFailure(message ?? '', diagnostic: diagnostic);
        }
        if (errorCode == 'PHONE_ALREADY_REGISTERED') {
          return PhoneAlreadyRegisteredFailure(
            message ?? '',
            diagnostic: diagnostic,
          );
        }
        return ConflictFailure(message ?? '', diagnostic: diagnostic);
      } else if (statusCode == 429) {
        return ServerFailure(
          message ?? '',
          code: FailureCode.tooManyRequests,
          diagnostic: diagnostic,
        );
      } else if (statusCode != null && statusCode >= 500) {
        return ServerFailure('', diagnostic: diagnostic);
      }

      return ServerFailure(
        message ?? '',
        code: FailureCode.unknown,
        diagnostic: diagnostic,
      );

    case DioExceptionType.cancel:
      return NetworkFailure(
        '',
        code: FailureCode.requestCancelled,
        diagnostic: e.message,
      );

    case DioExceptionType.unknown:
      return NetworkFailure(
        '',
        code: FailureCode.unknown,
        // Dio's own English text is a diagnostic, not a sentence for a user.
        diagnostic: e.message ?? e.error?.toString(),
      );
  }
}

/// The backend's `error` field doubles as a machine-checkable code, so an
/// all-caps token is never a sentence to show anybody.
final RegExp _machineCode = RegExp(r'^[A-Z][A-Z0-9_]*$');

/// The human sentence in the body, or null when there isn't one.
String? _humanMessage(dynamic data) {
  final message = _extractMessage(data);
  if (message == null) return null;
  final trimmed = message.trim();
  if (trimmed.isEmpty) return null;
  // _extractMessage falls back to the `error` field, which carries the code
  // when the body has no message. Showing `INSPECTOR_BUSY` to a user is worse
  // than showing nothing — the localized wording for the code is better.
  if (trimmed == _extractErrorCode(data) && _machineCode.hasMatch(trimmed)) {
    return null;
  }
  return trimmed;
}

String? _extractMessage(dynamic data) {
  if (data is Map<String, dynamic>) {
    final message = data['message'];
    // NestJS class-validator responses send `message` as a list of strings
    // (one per failed validator) rather than a single string — join them
    // into one readable line instead of showing Dart's raw "[a, b]" list
    // formatting (or, worse, crashing a `message as String` cast).
    if (message is List) {
      final joined = message
          .where((m) => m != null)
          .map((m) => m.toString())
          .join(', ');
      if (joined.isNotEmpty) return joined;
    } else if (message != null) {
      return message.toString();
    }
    if (data['error'] != null) {
      return data['error'].toString();
    }
  }
  return null;
}

/// The backend's `error` field doubles as a machine-checkable code (e.g.
/// `PHONE_ALREADY_REGISTERED`) for the handful of cases where a plain message string
/// isn't enough to drive different UI (see `GlobalExceptionFilter`, which
/// passes a thrown exception's `error` field through verbatim).
String? _extractErrorCode(dynamic data) {
  if (data is Map<String, dynamic> && data['error'] != null) {
    return data['error'].toString();
  }
  return null;
}

/// The backend's optional `retryAfterSeconds` (currently only sent with
/// OTP_RESEND_TOO_SOON) — null when absent or not a number.
int? _extractRetryAfterSeconds(dynamic data) {
  if (data is Map<String, dynamic>) {
    final value = data['retryAfterSeconds'];
    if (value is num) return value.round();
  }
  return null;
}

/// Status + backend code, for logs only. Never shown, never translated.
// l10n-ignore: Technical diagnostic (HTTP status + backend code) kept for logs
String _diagnostic(int? statusCode, String? errorCode) =>
    'HTTP $statusCode${errorCode == null ? '' : ' $errorCode'}';
