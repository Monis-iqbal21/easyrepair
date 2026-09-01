import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handygo_app/core/storage/local_cache_service.dart';
import 'package:handygo_app/core/storage/secure_storage_service.dart';
import 'package:handygo_app/features/notifications/data/datasources/notification_remote_datasource.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  for (final locale in ['en', 'ur_Latn', 'ur']) {
    test(
      'FCM registration sends selected $locale notification locale',
      () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
          ..interceptors.add(
            InterceptorsWrapper(
              onRequest: (options, handler) {
                expect(options.path, '/auth/fcm-token');
                expect(options.data, {
                  'token': 'device-token',
                  'locale': locale,
                });
                handler.resolve(
                  Response<void>(requestOptions: options, statusCode: 200),
                );
              },
            ),
          );
        final datasource = NotificationRemoteDatasourceImpl(
          dio,
          LocalCacheService(prefs),
          const SecureStorageService(FlutterSecureStorage()),
        );

        await datasource.saveFcmToken('device-token', locale: locale);
      },
    );
  }
}
