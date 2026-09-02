import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handygo_app/features/auth/data/datasources/auth_remote_datasource.dart';

typedef _Handler = Future<ResponseBody> Function(RequestOptions options);

class _FakeAdapter implements HttpClientAdapter {
  const _FakeAdapter(this.handler);

  final _Handler handler;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) => handler(options);
}

ResponseBody _success() => ResponseBody.fromString(
  jsonEncode({'success': true, 'data': {}}),
  200,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);

void main() {
  test(
    'deleteAccount sends the exact explicit confirmation sentinel',
    () async {
      RequestOptions? seen;
      final publicDio = Dio(BaseOptions(baseUrl: 'http://test'))
        ..httpClientAdapter = _FakeAdapter(
          (_) => fail('deleteAccount must use the authenticated Dio client'),
        );
      final authenticatedDio = Dio(BaseOptions(baseUrl: 'http://test'))
        ..httpClientAdapter = _FakeAdapter((options) async {
          seen = options;
          return _success();
        });
      final datasource = AuthRemoteDatasource(publicDio, authenticatedDio);

      await datasource.deleteAccount();

      expect(seen, isNotNull);
      expect(seen!.method, 'DELETE');
      expect(seen!.path, '/auth/account');
      expect(seen!.data, const {'confirmation': 'DELETE_MY_ACCOUNT'});
    },
  );
}
