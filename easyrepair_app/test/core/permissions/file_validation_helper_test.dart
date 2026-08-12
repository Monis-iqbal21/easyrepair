import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:handygo_app/core/permissions/file_validation_helper.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('file_validation_test');
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  File writeFile(String name, int sizeBytes) {
    final file = File('${tempDir.path}${Platform.pathSeparator}$name');
    file.writeAsBytesSync(List.filled(sizeBytes, 0));
    return file;
  }

  group('validateBookingAttachment', () {
    test('an allowed mime type under the size limit passes (null = valid)',
        () async {
      final file = writeFile('photo.jpg', 1024);
      final result = await validateBookingAttachment(file, 'image/jpeg');
      expect(result, isNull);
    });

    test('an unsupported mime type is rejected before the size is even checked',
        () async {
      final file = writeFile('doc.pdf', 1024);
      final result = await validateBookingAttachment(file, 'application/pdf');
      expect(result, FileValidationError.unsupportedType);
    });

    test('a file over the 50MB backend limit is rejected', () async {
      final file = writeFile('huge.mp4', bookingAttachmentMaxSizeBytes + 1);
      final result = await validateBookingAttachment(file, 'video/mp4');
      expect(result, FileValidationError.tooLarge);
    });

    test('a file exactly at the limit is accepted (limit is inclusive)',
        () async {
      final file = writeFile('exact.mp4', bookingAttachmentMaxSizeBytes);
      final result = await validateBookingAttachment(file, 'video/mp4');
      expect(result, isNull);
    });

    test('mirrors every mime type the backend actually allows '
        '(ALLOWED_MIME_TYPES in bookings.controller.ts)', () {
      expect(bookingAttachmentAllowedMimeTypes, {
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
      });
    });
  });
}
