import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handygo_app/core/storage/secure_storage_service.dart';

/// Builds a syntactically-real (unsigned) JWT carrying [sub] — mirrors the
/// shape `AuthService._signAccessToken` on the backend actually issues
/// (`{sub, phone, role}`), without needing a real signing key.
String _fakeJwt(Map<String, dynamic> payload) {
  String segment(Object value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  return '${segment({
        'alg': 'HS256',
      })}.${segment(payload)}.fake-signature';
}

/// Records every write, in order, against an in-memory map — swapped in via
/// [FlutterSecureStoragePlatform.instance] so [SecureStorageService] runs
/// against its real, unmodified implementation, never a stand-in for it.
class _RecordingPlatform extends FlutterSecureStoragePlatform {
  final Map<String, String> data = {};
  final List<String> writeOrder = [];

  @override
  Future<bool> containsKey({
    required String key,
    required Map<String, String> options,
  }) async => data.containsKey(key);

  @override
  Future<void> delete({
    required String key,
    required Map<String, String> options,
  }) async => data.remove(key);

  @override
  Future<void> deleteAll({required Map<String, String> options}) async =>
      data.clear();

  @override
  Future<String?> read({
    required String key,
    required Map<String, String> options,
  }) async => data[key];

  @override
  Future<Map<String, String>> readAll({
    required Map<String, String> options,
  }) async => data;

  @override
  Future<void> write({
    required String key,
    required String value,
    required Map<String, String> options,
  }) async {
    writeOrder.add(key);
    data[key] = value;
  }
}

void main() {
  late _RecordingPlatform platform;
  late SecureStorageService service;

  setUp(() {
    platform = _RecordingPlatform();
    FlutterSecureStoragePlatform.instance = platform;
    service = const SecureStorageService(FlutterSecureStorage());
  });

  group('saveTokens write order', () {
    test(
      'writes the refresh token before the access token — a crash between '
      'the two leaves the OLD access token + the NEW refresh token, which '
      'recovers on the very next request instead of only failing much '
      'later, outside the backend\'s rotation grace window',
      () async {
        await service.saveTokens(accessToken: 'access-1', refreshToken: 'refresh-1');

        expect(platform.writeOrder, ['refresh_token', 'access_token']);
      },
    );

    test('both tokens are readable after saving', () async {
      await service.saveTokens(accessToken: 'access-1', refreshToken: 'refresh-1');

      expect(await service.getAccessToken(), 'access-1');
      expect(await service.getRefreshToken(), 'refresh-1');
    });
  });

  group('clearTokens', () {
    test('removes both keys', () async {
      await service.saveTokens(accessToken: 'access-1', refreshToken: 'refresh-1');

      await service.clearTokens();

      expect(await service.getAccessToken(), isNull);
      expect(await service.getRefreshToken(), isNull);
    });
  });

  group('getCurrentUserId', () {
    test('decodes the sub claim out of the current access token', () async {
      await service.saveTokens(
        accessToken: _fakeJwt({'sub': 'u-42', 'phone': '+92300', 'role': 'CLIENT'}),
        refreshToken: 'refresh-1',
      );

      expect(await service.getCurrentUserId(), 'u-42');
    });

    test('returns null when there is no access token (logged out)', () async {
      expect(await service.getCurrentUserId(), isNull);
    });

    test('returns null for a malformed token instead of throwing — cache '
        'namespacing must degrade to "no account" rather than crash', () async {
      await service.saveTokens(accessToken: 'not-a-jwt', refreshToken: 'r1');

      expect(await service.getCurrentUserId(), isNull);
    });

    test('a different account\'s token yields a different id — this is what '
        'LocalCacheService relies on to keep accounts from ever seeing each '
        'other\'s cached data', () async {
      await service.saveTokens(
        accessToken: _fakeJwt({'sub': 'u-1'}),
        refreshToken: 'r1',
      );
      final first = await service.getCurrentUserId();

      await service.saveTokens(
        accessToken: _fakeJwt({'sub': 'u-2'}),
        refreshToken: 'r2',
      );
      final second = await service.getCurrentUserId();

      expect(first, 'u-1');
      expect(second, 'u-2');
      expect(first, isNot(second));
    });
  });
}
