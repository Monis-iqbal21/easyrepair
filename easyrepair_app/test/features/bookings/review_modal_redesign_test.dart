import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:handygo_app/core/errors/failures.dart';
import 'package:handygo_app/core/l10n/app_locale.dart';
import 'package:handygo_app/core/theme/app_semantic_colors.dart';
import 'package:handygo_app/core/theme/app_theme.dart';
import 'package:handygo_app/features/bookings/domain/entities/booking_entity.dart';
import 'package:handygo_app/features/bookings/domain/entities/update_booking_request.dart';
import 'package:handygo_app/features/bookings/domain/repositories/booking_repository.dart';
import 'package:handygo_app/features/bookings/presentation/providers/booking_providers.dart';
import 'package:handygo_app/features/bookings/presentation/widgets/review_modal.dart';
import 'package:handygo_app/l10n/app_localizations.dart';

import '../../support/l10n_test_app.dart';

BookingEntity _completed() => BookingEntity(
  id: 'booking-1',
  referenceId: '#ER-1042',
  serviceCategory: 'AC Repair',
  serviceEmoji: '❄️',
  status: BookingStatus.completed,
  urgency: BookingUrgency.normal,
  createdAt: DateTime(2026, 7, 30, 9),
  completedAt: DateTime(2026, 7, 30, 11),
  lane: BookingLane.inspection,
  finalPrice: 500,
  assignedWorker: const AssignedWorkerEntity(
    id: 'worker-1',
    firstName: 'Ali',
    lastName: 'Khan',
    rating: 4.6,
  ),
);

/// Records every review payload the modal sends, so the test can assert the
/// API contract is untouched by the redesign.
class _FakeBookingRepository implements BookingRepository {
  final requests = <ReviewRequest>[];
  Failure? submitFailure;
  Duration delay = Duration.zero;

  @override
  Future<Either<Failure, BookingEntity>> submitReview(
    ReviewRequest request,
  ) async {
    requests.add(request);
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    if (submitFailure != null) return Left(submitFailure!);
    return Right(_completed());
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not stubbed');
}

class _Pumped {
  _Pumped(this.repo, this.popped);
  final _FakeBookingRepository repo;
  final List<bool?> popped;
}

Future<_Pumped> _pumpModal(
  WidgetTester tester, {
  bool mandatory = false,
  AppLocale locale = AppLocale.romanUrdu,
  Failure? submitFailure,
  Duration delay = Duration.zero,
  TextScaler textScaler = TextScaler.noScaling,
}) async {
  final repo = _FakeBookingRepository()
    ..submitFailure = submitFailure
    ..delay = delay;
  final popped = <bool?>[];

  await tester.pumpWidget(
    ProviderScope(
      overrides: [bookingRepositoryProvider.overrideWithValue(repo)],
      child: localizedApp(
        Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: textScaler),
            child: Scaffold(
              body: Builder(
                builder: (inner) => Center(
                  child: ElevatedButton(
                    onPressed: () async {
                      popped.add(
                        await showDialog<bool>(
                          context: inner,
                          barrierDismissible: !mandatory,
                          builder: (_) => ReviewModal(
                            booking: _completed(),
                            mandatory: mandatory,
                          ),
                        ),
                      );
                    },
                    child: const Text('OPEN'),
                  ),
                ),
              ),
            ),
          ),
        ),
        locale: locale,
        theme: AppTheme.lightTheme,
      ),
    ),
  );
  await tester.tap(find.text('OPEN'));
  await tester.pumpAndSettle();
  return _Pumped(repo, popped);
}

Future<AppLocalizations> _l10nFor(AppLocale locale) =>
    AppLocalizations.delegate.load(locale.locale);

Finder get _submitBtn => find.byKey(const Key('review-submit-button'));
Finder get _stars => find.byIcon(Icons.star_rounded);

Future<void> _rate(WidgetTester tester, int stars) async {
  await tester.tap(_stars.at(stars - 1));
  await tester.pumpAndSettle();
}

/// How many stars currently read as chosen. Colour, not glyph, carries the
/// selection, and the expected colour is read from the palette itself so the
/// test never restates one of its own.
int _filledStars(WidgetTester tester) => tester
    .widgetList<Icon>(_stars)
    .where((icon) => icon.color == AppSemanticColors.light.warning)
    .length;

void main() {
  group('job context', () {
    testWidgets('names the Ustaad and the job being rated', (tester) async {
      await _pumpModal(tester);
      final l10n = await _l10nFor(AppLocale.romanUrdu);

      expect(find.text(l10n.reviewHowWasWork), findsOneWidget);
      expect(find.text('Ali Khan'), findsOneWidget);
      expect(find.text('AC Repair · #ER-1042'), findsOneWidget);
      // Initials stand in when there is no avatar image.
      expect(find.text('AK'), findsOneWidget);
    });

    testWidgets('mandatory mode explains itself and offers no way out', (
      tester,
    ) async {
      await _pumpModal(tester, mandatory: true);
      final l10n = await _l10nFor(AppLocale.romanUrdu);

      expect(find.text(l10n.reviewPromptBeforeContinuing), findsOneWidget);
      expect(find.byKey(const Key('review-later-button')), findsNothing);
    });

    testWidgets('the ordinary prompt keeps its "later" escape', (tester) async {
      final pumped = await _pumpModal(tester);

      await tester.tap(find.byKey(const Key('review-later-button')));
      await tester.pumpAndSettle();

      expect(pumped.repo.requests, isEmpty);
      expect(pumped.popped, [false]);
    });
  });

  group('rating selection', () {
    testWidgets('offers exactly five stars, none chosen to begin with', (
      tester,
    ) async {
      await _pumpModal(tester);
      expect(_stars, findsNWidgets(5));
      expect(_filledStars(tester), 0);
    });

    testWidgets('one star fills exactly one', (tester) async {
      await _pumpModal(tester);
      await _rate(tester, 1);
      expect(_filledStars(tester), 1);
    });

    testWidgets('five stars fills all five', (tester) async {
      await _pumpModal(tester);
      await _rate(tester, 5);
      expect(_filledStars(tester), 5);
    });

    testWidgets('each star keeps a 48px tap target', (tester) async {
      await _pumpModal(tester);
      for (var i = 0; i < 5; i++) {
        final size = tester.getSize(
          find
              .ancestor(of: _stars.at(i), matching: find.byType(SizedBox))
              .first,
        );
        expect(size.width, greaterThanOrEqualTo(48));
        expect(size.height, greaterThanOrEqualTo(48));
      }
    });
  });

  group('validation is unchanged', () {
    testWidgets('submitting with no rating sends nothing and says why', (
      tester,
    ) async {
      final pumped = await _pumpModal(tester);
      final l10n = await _l10nFor(AppLocale.romanUrdu);

      await tester.tap(_submitBtn);
      await tester.pumpAndSettle();

      expect(pumped.repo.requests, isEmpty);
      expect(find.byKey(const Key('review-rating-error')), findsOneWidget);
      expect(find.text(l10n.reviewSelectRating), findsOneWidget);

      // Picking a star clears the message.
      await _rate(tester, 3);
      expect(find.byKey(const Key('review-rating-error')), findsNothing);
    });

    testWidgets('a comment stays optional', (tester) async {
      final pumped = await _pumpModal(tester);
      await _rate(tester, 4);
      await tester.tap(_submitBtn);
      await tester.pumpAndSettle();

      expect(pumped.repo.requests, hasLength(1));
      expect(pumped.repo.requests.single.rating, 4);
      expect(pumped.repo.requests.single.comment, isNull);
    });
  });

  group('payload', () {
    testWidgets('sends the booking id, the rating and the trimmed comment', (
      tester,
    ) async {
      final pumped = await _pumpModal(tester);
      await _rate(tester, 5);
      await tester.enterText(
        find.byKey(const Key('review-comment-field')),
        '  Bohat acha kaam  ',
      );
      await tester.pumpAndSettle();
      await tester.tap(_submitBtn);
      await tester.pumpAndSettle();

      final request = pumped.repo.requests.single;
      expect(request.bookingId, 'booking-1');
      expect(request.rating, 5);
      expect(request.comment, 'Bohat acha kaam');
    });

    testWidgets('a whitespace-only comment is sent as null, not as spaces', (
      tester,
    ) async {
      final pumped = await _pumpModal(tester);
      await _rate(tester, 2);
      await tester.enterText(
        find.byKey(const Key('review-comment-field')),
        '     ',
      );
      await tester.pumpAndSettle();
      await tester.tap(_submitBtn);
      await tester.pumpAndSettle();

      expect(pumped.repo.requests.single.comment, isNull);
    });
  });

  group('submission states', () {
    testWidgets('shows a spinner while the review is in flight', (
      tester,
    ) async {
      await _pumpModal(tester, delay: const Duration(milliseconds: 300));
      await _rate(tester, 5);

      await tester.tap(_submitBtn);
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.pumpAndSettle();
    });

    testWidgets('a second tap while in flight cannot send a duplicate', (
      tester,
    ) async {
      final pumped = await _pumpModal(
        tester,
        delay: const Duration(milliseconds: 300),
      );
      await _rate(tester, 5);

      await tester.tap(_submitBtn);
      await tester.pump();
      await tester.tap(_submitBtn, warnIfMissed: false);
      await tester.pump();

      expect(pumped.repo.requests, hasLength(1));
      await tester.pumpAndSettle();
      expect(pumped.repo.requests, hasLength(1));
    });

    testWidgets('success closes the modal with true and confirms it', (
      tester,
    ) async {
      final pumped = await _pumpModal(tester);
      final l10n = await _l10nFor(AppLocale.romanUrdu);
      await _rate(tester, 5);

      await tester.tap(_submitBtn);
      await tester.pump();
      await tester.pump();

      expect(pumped.popped, [true]);
      expect(find.text(l10n.reviewSubmitSuccess), findsOneWidget);
      await tester.pumpAndSettle();
    });

    testWidgets('failure keeps the modal open, rated, and retryable', (
      tester,
    ) async {
      final pumped = await _pumpModal(
        tester,
        submitFailure: const ServerFailure('boom'),
      );
      await _rate(tester, 3);

      await tester.tap(_submitBtn);
      await tester.pumpAndSettle();

      // Still open with the rating intact, and nothing was popped.
      expect(_submitBtn, findsOneWidget);
      expect(_filledStars(tester), 3);
      expect(pumped.popped, isEmpty);

      // Retry goes through.
      await tester.tap(_submitBtn);
      await tester.pumpAndSettle();
      expect(pumped.repo.requests, hasLength(2));
    });
  });

  group('localization', () {
    for (final (locale, submitLabel) in [
      (AppLocale.english, 'Submit Review'),
      (AppLocale.urdu, 'ریویو جمع کریں'),
      (AppLocale.romanUrdu, 'Review Submit Karein'),
    ]) {
      testWidgets('${locale.storageValue} renders its own strings', (
        tester,
      ) async {
        await _pumpModal(tester, locale: locale);
        final l10n = await _l10nFor(locale);

        expect(find.text(submitLabel), findsOneWidget);
        expect(find.text(l10n.reviewHowWasWork), findsOneWidget);
        expect(find.text(l10n.reviewLater), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('responsive', () {
    for (final width in [320.0, 360.0, 390.0, 430.0]) {
      testWidgets('lays out at ${width.toInt()}px with no overflow', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await _pumpModal(tester, locale: AppLocale.urdu);

        expect(tester.takeException(), isNull);
        expect(_submitBtn, findsOneWidget);
        expect(_stars, findsNWidgets(5));
      });
    }

    testWidgets('survives a 2.0 text scale at 320px', (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await _pumpModal(
        tester,
        locale: AppLocale.urdu,
        textScaler: const TextScaler.linear(2.0),
      );

      expect(tester.takeException(), isNull);
      expect(_submitBtn, findsOneWidget);
    });
  });
}
