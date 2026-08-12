import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../l10n/l10n_extensions.dart';

enum MediaPermissionKind { camera, gallery }

Permission _permissionFor(MediaPermissionKind kind) =>
    kind == MediaPermissionKind.camera ? Permission.camera : Permission.photos;

/// Picks an image via [source], never letting a denied/permanently-denied
/// permission or a raw platform exception reach the user.
///
/// Returns the picked file, or `null` when the user cancelled *or*
/// permission was unavailable — in the permission case a friendly, localized
/// recovery SnackBar (with an "Open Settings" action when appropriate) is
/// shown before returning, so callers only need to handle "no file".
Future<XFile?> pickImageWithRecovery(
  BuildContext context, {
  required ImagePicker picker,
  required ImageSource source,
  int? imageQuality,
  double? maxWidth,
}) {
  final kind =
      source == ImageSource.camera ? MediaPermissionKind.camera : MediaPermissionKind.gallery;
  return runPickerWithRecovery<XFile?>(
    context,
    kind,
    () => picker.pickImage(source: source, imageQuality: imageQuality, maxWidth: maxWidth),
  );
}

/// Generic version of [pickImageWithRecovery] for picker calls whose
/// signature doesn't fit that helper (`pickVideo`, `pickMultiImage`, …).
/// [kind] tells the recovery message which permission was actually needed —
/// pass [MediaPermissionKind.camera] for [ImageSource.camera] calls,
/// [MediaPermissionKind.gallery] otherwise.
Future<T?> runPickerWithRecovery<T>(
  BuildContext context,
  MediaPermissionKind kind,
  Future<T> Function() pick,
) async {
  final permission = _permissionFor(kind);

  final currentStatus = await permission.status;
  if (currentStatus.isPermanentlyDenied) {
    if (context.mounted) {
      _showMediaPermissionRecovery(context, kind, permanentlyDenied: true);
    }
    return null;
  }

  try {
    return await pick();
  } on PlatformException catch (e) {
    final isPermissionIssue = e.code == 'camera_access_denied' ||
        e.code == 'photo_access_denied' ||
        e.code == 'no_available_camera';
    if (!context.mounted) return null;
    if (isPermissionIssue) {
      final nowStatus = await permission.status;
      if (!context.mounted) return null;
      _showMediaPermissionRecovery(
        context,
        kind,
        permanentlyDenied: nowStatus.isPermanentlyDenied,
      );
    } else {
      _showSnack(context, context.l10n.errorUnknown);
    }
    return null;
  }
}

void _showMediaPermissionRecovery(
  BuildContext context,
  MediaPermissionKind kind, {
  required bool permanentlyDenied,
}) {
  final l10n = context.l10n;
  final message = kind == MediaPermissionKind.camera
      ? l10n.cameraPermissionDeniedMessage
      : l10n.galleryPermissionDeniedMessage;

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      duration: const Duration(seconds: 5),
      action: permanentlyDenied
          ? SnackBarAction(label: l10n.commonOpenSettings, onPressed: openAppSettings)
          : null,
    ),
  );
}

void _showSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}
