import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  static const _accessTokenKey = 'access_token';
  static const _refreshTokenKey = 'refresh_token';

  final FlutterSecureStorage _storage;

  const SecureStorageService(this._storage);

  /// Writes the refresh token FIRST, then the access token — deliberately
  /// sequential, not concurrent. `flutter_secure_storage` has no multi-key
  /// transaction, so this ordering is what "atomic enough" means here: if
  /// the app is killed between the two writes, the device is left holding
  /// the OLD access token + the NEW refresh token, never the reverse.
  ///
  /// That matters because of what happens next either way:
  ///  * OLD access token + NEW refresh token: the very next request 401s on
  ///    the stale access token, and AuthInterceptor immediately refreshes
  ///    using the refresh token already saved here — recovers on the spot.
  ///  * NEW access token + OLD (backend-rotated-away) refresh token — the
  ///    ordering this avoids — would keep working for up to the access
  ///    token's full remaining lifetime, then fail far outside the backend's
  ///    short rotation grace window, surfacing as a real, avoidable logout.
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _storage.write(key: _refreshTokenKey, value: refreshToken);
    await _storage.write(key: _accessTokenKey, value: accessToken);
  }

  Future<String?> getAccessToken() => _storage.read(key: _accessTokenKey);

  Future<String?> getRefreshToken() => _storage.read(key: _refreshTokenKey);

  Future<void> clearTokens() async {
    await Future.wait([
      _storage.delete(key: _accessTokenKey),
      _storage.delete(key: _refreshTokenKey),
    ]);
  }

  /// The signed-in account's id, derived from the current access token's
  /// `sub` claim (see `AuthService._signAccessToken` on the backend) —
  /// deliberately not a separate stored value: it can never go stale or
  /// outlive a token clear, and it's `null` in exactly the cases where
  /// caller code must not read/write per-account cache (no session).
  ///
  /// Used only to namespace [LocalCacheService] entries — never sent
  /// anywhere and never trusted for anything security-sensitive (the
  /// backend independently authenticates every request via the bearer
  /// token itself).
  Future<String?> getCurrentUserId() async {
    final token = await getAccessToken();
    if (token == null) return null;
    return _decodeJwtSubClaim(token);
  }

  static String? _decodeJwtSubClaim(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      final normalized = base64Url.normalize(parts[1]);
      final payload =
          jsonDecode(utf8.decode(base64Url.decode(normalized))) as Map<String, dynamic>;
      return payload['sub'] as String?;
    } catch (_) {
      return null;
    }
  }
}

final secureStorageServiceProvider = Provider<SecureStorageService>((ref) {
  return const SecureStorageService(FlutterSecureStorage());
});
