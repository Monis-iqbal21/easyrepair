import 'dart:io';

/// Mirrors the backend's own limits for `POST /bookings/:id/attachments`
/// (see `ALLOWED_MIME_TYPES` / `MAX_FILE_SIZE` in `bookings.controller.ts`)
/// so an oversized or unsupported file is caught immediately at pick time
/// instead of only after a failed upload round-trip. Keep these two in sync
/// with the backend if its limits ever change.
const bookingAttachmentMaxSizeBytes = 50 * 1024 * 1024; // 50 MB

const bookingAttachmentAllowedMimeTypes = {
  'image/jpeg',
  'image/png',
  'image/webp',
  'image/heic',
  'video/mp4',
  'video/quicktime',
  'video/3gpp',
  'audio/mpeg',
  'audio/mp4',
  'audio/aac',
  'audio/x-m4a',
  'audio/ogg',
  'audio/wav',
};

enum FileValidationError { unsupportedType, tooLarge }

/// Validates a picked booking attachment against the backend's own accepted
/// mime types and size limit. Returns `null` when the file is fine to
/// upload, or the specific reason it was rejected.
Future<FileValidationError?> validateBookingAttachment(
  File file,
  String mimeType,
) async {
  if (!bookingAttachmentAllowedMimeTypes.contains(mimeType)) {
    return FileValidationError.unsupportedType;
  }
  final size = await file.length();
  if (size > bookingAttachmentMaxSizeBytes) {
    return FileValidationError.tooLarge;
  }
  return null;
}
