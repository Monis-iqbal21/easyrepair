import 'package:flutter/material.dart';

import '../l10n/l10n_extensions.dart';
import 'location_availability.dart';

/// Shows the one localized, actionable message for [status] — never a raw
/// platform/plugin exception. A no-op for [LocationAvailability.available]
/// (nothing to recover from).
///
/// [onRetry] is used for the two states where re-attempting the same fetch
/// might succeed ([LocationAvailability.permissionDenied] re-shows the OS
/// permission dialog; [LocationAvailability.unavailable] just retries the
/// fix). The Settings-opening states ([permissionPermanentlyDenied],
/// [serviceDisabled]) always route to the matching system screen instead —
/// retrying without the user leaving the app cannot succeed.
void showLocationRecoverySnack(
  BuildContext context,
  LocationAvailability status, {
  VoidCallback? onRetry,
}) {
  if (status == LocationAvailability.available) return;
  final l10n = context.l10n;

  late final String message;
  late final String actionLabel;
  late final VoidCallback action;

  switch (status) {
    case LocationAvailability.permissionDenied:
      message = l10n.locationPermissionRequiredMessage;
      actionLabel = l10n.locationAllowAction;
      action = onRetry ?? () {};
    case LocationAvailability.permissionPermanentlyDenied:
      message = l10n.locationPermanentlyDeniedMessage;
      actionLabel = l10n.commonOpenSettings;
      action = openAppPermissionSettings;
    case LocationAvailability.serviceDisabled:
      message = l10n.locationGpsOffMessage;
      actionLabel = l10n.locationTurnOnAction;
      action = openLocationServicesSettings;
    case LocationAvailability.unavailable:
      message = l10n.locationUnavailableRetryMessage;
      actionLabel = l10n.commonRetry;
      action = onRetry ?? () {};
    case LocationAvailability.available:
      return; // unreachable — guarded above
  }

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      duration: const Duration(seconds: 5),
      action: SnackBarAction(label: actionLabel, onPressed: action),
    ),
  );
}
