import 'package:flutter_test/flutter_test.dart';
import 'package:handygo_app/core/data/cache_policy.dart';

/// [CachePolicy] is the single place HandyGo states how long each KIND of
/// cached read may be shown offline. These tests pin the product rules
/// themselves, so a future refactor cannot quietly change how long a Worker
/// keeps seeing a stale marketplace or how long an account's own history
/// survives without a network.
void main() {
  group('CachePolicy.newJobs — the approved 24h marketplace rule', () {
    test('is exactly 24 hours', () {
      // This is a product decision, not an implementation detail. If this
      // test fails, the New Jobs offline window changed and needs sign-off.
      expect(CachePolicy.newJobs.maxAge, const Duration(hours: 24));
    });

    test('serves a cache saved just inside the window', () {
      final now = DateTime(2026, 8, 18, 12);
      expect(
        CachePolicy.newJobs.allowsFallback(
          now.subtract(const Duration(hours: 23, minutes: 59)),
          now: now,
        ),
        isTrue,
      );
    });

    test('refuses a cache saved past the window', () {
      final now = DateTime(2026, 8, 18, 12);
      expect(
        CachePolicy.newJobs.allowsFallback(
          now.subtract(const Duration(hours: 24, minutes: 1)),
          now: now,
        ),
        isFalse,
      );
    });
  });

  group('CachePolicy.accountHistory — last-known snapshot, no expiry', () {
    test('has no maxAge at all', () {
      expect(CachePolicy.accountHistory.maxAge, isNull);
    });

    test('still serves a snapshot saved a year ago', () {
      final now = DateTime(2026, 8, 18);
      expect(
        CachePolicy.accountHistory.allowsFallback(
          now.subtract(const Duration(days: 365)),
          now: now,
        ),
        isTrue,
      );
      // Age alone never makes a completed job or past booking wrong — the
      // offline banner already tells the user this is saved data.
    });

    test('is the default policy, so an unannotated cached read keeps its '
        'existing last-known-snapshot behaviour', () {
      // Guards the migration from the old optional `maxAge` parameter: every
      // call site that passed nothing must still behave as "no expiry".
      expect(CachePolicy.accountHistory.maxAge, isNull);
      expect(CachePolicy.accountHistory.isOfflineFallbackDisabled, isFalse);
    });
  });

  group('CachePolicy.liveDiscovery — never trustworthy offline', () {
    test('disables offline fallback entirely, even for a cache saved a '
        'second ago', () {
      final now = DateTime(2026, 8, 18, 12);
      expect(CachePolicy.liveDiscovery.isOfflineFallbackDisabled, isTrue);
      expect(
        CachePolicy.liveDiscovery.allowsFallback(
          now.subtract(const Duration(seconds: 1)),
          now: now,
        ),
        isFalse,
      );
    });
  });

  group('CachePolicy.referenceData', () {
    test('allows a long window for slow-changing catalog data', () {
      final now = DateTime(2026, 8, 18);
      expect(
        CachePolicy.referenceData.allowsFallback(
          now.subtract(const Duration(days: 6)),
          now: now,
        ),
        isTrue,
      );
      expect(
        CachePolicy.referenceData.allowsFallback(
          now.subtract(const Duration(days: 8)),
          now: now,
        ),
        isFalse,
      );
    });
  });
}
