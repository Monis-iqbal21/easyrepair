import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handygo_app/core/errors/failures.dart';
import 'package:handygo_app/core/presentation/widgets/resource_unavailable_view.dart';

void main() {
  group('isResourceUnavailableFailure', () {
    test('true for NotFoundFailure (404 — the resource is gone)', () {
      expect(isResourceUnavailableFailure(const NotFoundFailure('')), isTrue);
    });

    test('true for ForbiddenFailure (403 — no longer accessible to this account)', () {
      expect(isResourceUnavailableFailure(const ForbiddenFailure('')), isTrue);
    });

    test('false for a transient NetworkFailure — this must stay on the '
        'normal Retry error path, not the dead-end resource-unavailable one',
        () {
      expect(
        isResourceUnavailableFailure(
          const NetworkFailure('', code: FailureCode.noInternet),
        ),
        isFalse,
      );
    });

    test('false for a 5xx ServerFailure — transient, not "gone"', () {
      expect(isResourceUnavailableFailure(const ServerFailure('')), isFalse);
    });

    test('false for null / a non-Failure error', () {
      expect(isResourceUnavailableFailure(null), isFalse);
      expect(isResourceUnavailableFailure(Exception('boom')), isFalse);
    });
  });

  group('ResourceUnavailableView', () {
    testWidgets('renders the given message and action label, and never '
        'renders a Retry-labelled control of its own', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: ResourceUnavailableView(
            message: 'This booking is no longer available.',
            actionLabel: 'Go to My Bookings',
            onAction: () => tapped = true,
          ),
        ),
      );

      expect(find.text('This booking is no longer available.'), findsOneWidget);
      expect(find.text('Go to My Bookings'), findsOneWidget);
      expect(find.text('Retry'), findsNothing);

      await tester.tap(find.text('Go to My Bookings'));
      expect(tapped, isTrue);
    });
  });
}
