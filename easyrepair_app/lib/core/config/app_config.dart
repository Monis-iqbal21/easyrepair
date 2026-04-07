import 'package:flutter/foundation.dart';

class AppConfig {
  // Override manually when needed:
  // flutter run --dart-define=API_BASE_URL=https://easyrepair-production.up.railway.app/api/v1 --dart-define=WS_URL=https://easyrepair-production.up.railway.app
  static const String _envApiBaseUrl = String.fromEnvironment('API_BASE_URL');
  static const String _envWsUrl = String.fromEnvironment('WS_URL');

  // Default live backend
  static const String _prodApiBaseUrl =
      'https://easyrepair-production.up.railway.app/api/v1';
  static const String _prodWsUrl =
      'https://easyrepair-production.up.railway.app';

  static const int _port = 3000;

  static String get apiBaseUrl {
    if (_envApiBaseUrl.isNotEmpty) return _envApiBaseUrl;
    return _prodApiBaseUrl;
  }

  static String get wsUrl {
    if (_envWsUrl.isNotEmpty) return _envWsUrl;
    return _prodWsUrl;
  }

  static const String flavor = String.fromEnvironment(
    'FLAVOR',
    defaultValue: 'client',
  );

  static const String googleMapsApiKey = String.fromEnvironment(
    'GOOGLE_MAPS_API_KEY',
    defaultValue: '',
  );
}
