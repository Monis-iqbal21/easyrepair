import '../../l10n/app_localizations.dart';
import 'failures.dart';

/// Turns an error into the sentence a user reads.
///
/// This is the only place a [Failure] becomes language. Two rules hold here:
///
/// * A human sentence written on the backend (`Failure.message`) is shown
///   exactly as it arrived. It is not this app's copy, so it is never
///   machine-translated and never rewritten.
/// * Otherwise the app-owned [FailureCode] is rendered through
///   `AppLocalizations`, so the same failure reads correctly in English, Urdu
///   and Roman Urdu.
///
/// [fallback] is the screen's own wording for "this particular action failed"
/// and wins whenever the failure carries nothing more specific.
String failureMessage(
  AppLocalizations l10n,
  Object? error, {
  String? fallback,
}) {
  if (error is! Failure) return fallback ?? l10n.errorUnknown;
  if (error.message.trim().isNotEmpty) return error.message.trim();
  return failureCodeMessage(l10n, error.code, fallback: fallback);
}

/// The localized wording for an app-owned [FailureCode].
String failureCodeMessage(
  AppLocalizations l10n,
  FailureCode code, {
  String? fallback,
}) {
  return switch (code) {
    FailureCode.noInternet => l10n.errorNoInternet,
    FailureCode.timeout => l10n.errorTimeout,
    FailureCode.requestCancelled => l10n.errorRequestCancelled,
    FailureCode.invalidRequest => l10n.errorInvalidRequest,
    FailureCode.unauthorized => l10n.errorSessionExpired,
    FailureCode.forbidden => l10n.errorForbidden,
    FailureCode.notFound => l10n.errorNotFound,
    FailureCode.conflict => l10n.errorConflict,
    FailureCode.tooManyRequests => l10n.errorTooManyRequests,
    FailureCode.server => l10n.errorServer,
    FailureCode.smsSendFailed => l10n.errorSmsSendFailed,
    FailureCode.otpResendTooSoon => l10n.errorOtpResendTooSoon,
    // The backend always writes the specific sentence for a rejected code
    // ("OTP ghalat hai.", "Code expire ho gaya hai…"), so `failureMessage`
    // returns that before it ever reaches this switch. This branch is the
    // safety net for a code with no message at all.
    FailureCode.otpRejected => fallback ?? l10n.errorUnknown,
    FailureCode.inspectorBusy => l10n.errorInspectorBusy,
    FailureCode.phoneNotRegistered => l10n.errorPhoneNotRegistered,
    FailureCode.phoneAlreadyRegistered => l10n.errorPhoneAlreadyRegistered,
    FailureCode.offlineActionBlocked => l10n.errorOfflineActionBlocked,
    // Nothing specific is known — the screen knows better than this file
    // which action the user was trying to complete.
    FailureCode.unknown => fallback ?? l10n.errorUnknown,
  };
}
