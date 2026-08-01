import 'package:dio/dio.dart';
import 'failures.dart';

/// Turns a [DioException] into a [Failure].
///
/// This file is deliberately free of user-facing wording. It decides *what*
/// went wrong ([FailureCode]) and passes through any human sentence the
/// backend wrote; the language the user reads is chosen later, in
/// `failure_messages.dart`, from `AppLocalizations`.
Failure dioExceptionToFailure(DioException e) {
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

      if (statusCode == 400) {
        return ValidationFailure(message ?? '', diagnostic: diagnostic);
      } else if (statusCode == 401) {
        return UnauthorizedFailure('', diagnostic: diagnostic);
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
        if (errorCode == 'PHONE_IS_WORKER') {
          return WorkerPhoneConflictFailure(
            message ?? '',
            diagnostic: diagnostic,
          );
        }
        if (errorCode == 'PHONE_IS_CLIENT') {
          return ClientPhoneConflictFailure(
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
/// `PHONE_IS_WORKER`) for the handful of cases where a plain message string
/// isn't enough to drive different UI (see `GlobalExceptionFilter`, which
/// passes a thrown exception's `error` field through verbatim).
String? _extractErrorCode(dynamic data) {
  if (data is Map<String, dynamic> && data['error'] != null) {
    return data['error'].toString();
  }
  return null;
}

/// Status + backend code, for logs only. Never shown, never translated.
// l10n-ignore: Technical diagnostic (HTTP status + backend code) kept for logs
String _diagnostic(int? statusCode, String? errorCode) =>
    'HTTP $statusCode${errorCode == null ? '' : ' $errorCode'}';
