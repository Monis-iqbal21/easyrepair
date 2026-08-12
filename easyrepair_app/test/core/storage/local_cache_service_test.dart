import 'package:flutter_test/flutter_test.dart';
import 'package:handygo_app/core/storage/local_cache_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<LocalCacheService> _service() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return LocalCacheService(prefs);
}

void main() {
  group('LocalCacheService', () {
    test('read returns null when nothing was ever cached', () async {
      final cache = await _service();

      expect(cache.read('u1', 'bookings'), isNull);
    });

    test('write then read round-trips the raw JSON payload', () async {
      final cache = await _service();
      final payload = [
        {'id': 'b1', 'status': 'PENDING'},
      ];

      await cache.write('u1', 'bookings', payload);
      final entry = cache.read('u1', 'bookings');

      expect(entry, isNotNull);
      expect(entry!.data, payload);
    });

    test('write stamps a savedAt timestamp close to now', () async {
      final cache = await _service();
      final before = DateTime.now();

      await cache.write('u1', 'bookings', {'a': 1});
      final entry = cache.read('u1', 'bookings')!;

      expect(
        entry.savedAt.difference(before).inSeconds.abs(),
        lessThan(5),
      );
    });

    test('a fresh write replaces the previously cached value', () async {
      final cache = await _service();

      await cache.write('u1', 'bookings', {'status': 'PENDING'});
      await cache.write('u1', 'bookings', {'status': 'ACCEPTED'});

      final entry = cache.read('u1', 'bookings')!;
      expect(entry.data, {'status': 'ACCEPTED'});
    });

    test('remove deletes a single key without touching others', () async {
      final cache = await _service();
      await cache.write('u1', 'bookings', {'a': 1});
      await cache.write('u1', 'profile', {'b': 2});

      await cache.remove('u1', 'bookings');

      expect(cache.read('u1', 'bookings'), isNull);
      expect(cache.read('u1', 'profile'), isNotNull);
    });

    group('per-account scoping', () {
      test('the same key never collides across two different accounts', () async {
        final cache = await _service();

        await cache.write('u1', 'bookings', {'owner': 'u1'});
        await cache.write('u2', 'bookings', {'owner': 'u2'});

        expect(cache.read('u1', 'bookings')!.data, {'owner': 'u1'});
        expect(cache.read('u2', 'bookings')!.data, {'owner': 'u2'});
      });

      test(
        'a different account signing in on this device cannot read the '
        'previous account\'s cached data',
        () async {
          final cache = await _service();
          await cache.write('u1', 'bookings', {'owner': 'u1-private-data'});

          // u2 never wrote to 'bookings' — the read must be empty, not a
          // leak of u1's entry.
          expect(cache.read('u2', 'bookings'), isNull);
        },
      );

      test('clearUser wipes only that account\'s entries', () async {
        final cache = await _service();
        await cache.write('u1', 'bookings', {'a': 1});
        await cache.write('u1', 'profile', {'b': 2});
        await cache.write('u2', 'bookings', {'c': 3});

        await cache.clearUser('u1');

        expect(cache.read('u1', 'bookings'), isNull);
        expect(cache.read('u1', 'profile'), isNull);
        expect(cache.read('u2', 'bookings'), isNotNull, reason: 'u2 untouched');
      });
    });

    test('a corrupt stored envelope is treated as no cache, not a crash', () async {
      SharedPreferences.setMockInitialValues({
        'hg_cache_v1:u1:bookings': 'not valid json{{{',
      });
      final prefs = await SharedPreferences.getInstance();
      final cache = LocalCacheService(prefs);

      expect(cache.read('u1', 'bookings'), isNull);
    });
  });
}
