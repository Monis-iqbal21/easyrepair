import 'package:flutter_test/flutter_test.dart';
import 'package:handygo_app/core/utils/support_search.dart';

void main() {
  group('normalizeSupportQuery', () {
    test('lowercases, strips punctuation and spaces', () {
      expect(normalizeSupportQuery('  Handy-Go!  '), 'handygo');
      expect(normalizeSupportQuery('HANDY GO'), 'handygo');
    });

    test('collapses repeated characters', () {
      expect(normalizeSupportQuery('suuuppppport'), 'suport');
      expect(normalizeSupportQuery('support'), 'suport');
      expect(normalizeSupportQuery('heeelp'), 'help');
    });

    test('is empty for a query with no letters or digits', () {
      expect(normalizeSupportQuery('   ...  '), '');
    });
  });

  group('matchesSupport — intended queries', () {
    // Exact aliases, the Roman Urdu terms, and realistic typos.
    const shouldMatch = <String>[
      'support',
      'Support',
      'suport',
      'soport',
      'saport',
      'suppot',
      'supprt',
      'handygo',
      'handy go',
      'HandyGo Support',
      'help',
      'madad',
      'madat',
      'shikayat',
      'shikayet',
      'complaint',
      'complain',
      'masla',
      'maslaa',
    ];

    for (final query in shouldMatch) {
      test('"$query" surfaces Support', () {
        expect(matchesSupport(query), isTrue);
      });
    }

    test('an empty box keeps Support pinned', () {
      expect(matchesSupport(''), isTrue);
      expect(matchesSupport('   '), isTrue);
    });
  });

  group('matchesSupport — unrelated queries', () {
    // Typical searches for a worker, a trade or a booking. None of these may
    // surface Support, or the pin becomes noise on every search.
    const shouldNotMatch = <String>[
      'plumber',
      'electrician',
      'ali',
      'ahmed',
      'sara khan',
      'booking',
      'invoice',
      'carpenter',
      'painting',
      'inspection',
      'quotation',
      'thanks',
    ];

    for (final query in shouldNotMatch) {
      test('"$query" does not surface Support', () {
        expect(matchesSupport(query), isFalse);
      });
    }
  });

  test('tolerance is bounded — a far-off word never matches', () {
    // 'supermarket' shares a prefix-ish shape with 'support' but is well
    // beyond the edit-distance bound.
    expect(matchesSupport('supermarket'), isFalse);
  });
}
