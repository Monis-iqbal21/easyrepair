import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:handygo_app/core/errors/failures.dart';
import 'package:handygo_app/features/worker/domain/entities/worker_profile_entity.dart';
import 'package:handygo_app/features/worker/domain/entities/worker_skill_entity.dart';
import 'package:handygo_app/features/worker/domain/entities/worker_stats_entity.dart';
import 'package:handygo_app/features/worker/data/repositories/worker_repository_impl.dart';
import 'package:handygo_app/features/worker/domain/repositories/worker_repository.dart';
import 'package:handygo_app/features/worker/presentation/pages/worker_profile_details_page.dart';

import '../../support/l10n_test_app.dart';

/// The approved Ustaad's own record.
///
/// Two things matter here: everything the Ustaad submitted is actually shown
/// back to them, and none of it is editable. An approved profile is what the
/// admin reviewed and what the signed agreement PDFs were generated against,
/// so a stray text field would let a CNIC or legal name drift away from
/// documents that are already sealed.

WorkerProfileEntity _approved() => WorkerProfileEntity(
      id: 'worker-1',
      userId: 'user-1',
      firstName: 'Ali',
      lastName: 'Khan',
      status: 'ACTIVE',
      verificationStatus: 'VERIFIED',
      availabilityStatus: AvailabilityStatus.offline,
      rating: 4.8,
      totalRatings: 12,
      skills: [
        const WorkerSkillEntity(
          id: 'skill-1',
          categoryId: 'cat-1',
          categoryName: 'Electrician',
          yearsExperience: 7,
        ),
        const WorkerSkillEntity(
          id: 'skill-2',
          categoryId: 'cat-2',
          categoryName: 'AC Technician',
          yearsExperience: 3,
        ),
      ],
      stats: const WorkerStatsEntity(completedJobs: 40, activeJobs: 1),
      fullLegalName: 'Muhammad Ali Khan',
      fatherName: 'Abdul Rehman Khan',
      dateOfBirth: '1990-04-12',
      residentialAddress: 'House 12, Karachi',
      emergencyContact: 'Bilal, 03001234567',
      cnicNumber: '42101-1234567-1',
      cnicFrontUrl: 'https://cdn.test/f.jpg',
      cnicBackUrl: 'https://cdn.test/b.jpg',
      liveSelfieUrl: 'https://cdn.test/photo.jpg',
      onboardingStatus: 'APPROVED',
    );

class _FakeRepo implements WorkerRepository {
  _FakeRepo(this.profile);
  final WorkerProfileEntity profile;

  @override
  Future<Either<Failure, WorkerProfileEntity>> getProfile() async =>
      Right(profile);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not stubbed');
}

Future<void> _pump(WidgetTester tester, WorkerProfileEntity profile) async {
  tester.view.physicalSize = const Size(1080, 3200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await tester.pumpWidget(
    ProviderScope(
      overrides: [workerRepositoryProvider.overrideWithValue(_FakeRepo(profile))],
      child: localizedApp(const WorkerProfileDetailsPage()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows every field the Ustaad submitted', (tester) async {
    await _pump(tester, _approved());

    for (final value in const [
      'Muhammad Ali Khan',
      'Abdul Rehman Khan',
      '1990-04-12',
      '42101-1234567-1',
      'House 12, Karachi',
      'Bilal, 03001234567',
      '7',
      'VERIFIED',
      'APPROVED',
    ]) {
      expect(find.text(value), findsWidgets, reason: '$value was not shown');
    }
    // Both skills, and the main trade named separately.
    expect(find.text('Electrician'), findsWidgets);
    expect(find.text('AC Technician'), findsWidgets);
  });

  testWidgets('is read-only — no inputs, no save, no resubmit', (tester) async {
    await _pump(tester, _approved());

    expect(find.byType(TextField), findsNothing);
    expect(find.byType(TextFormField), findsNothing);
    expect(find.byType(Checkbox), findsNothing);
    expect(find.byType(Switch), findsNothing);
    expect(find.byType(ElevatedButton), findsNothing);
    expect(find.text('Submit for Approval'), findsNothing);
    expect(find.text('Save'), findsNothing);
  });

  testWidgets('says plainly that the details are locked', (tester) async {
    await _pump(tester, _approved());

    expect(
      find.text(
        'Your profile is approved. These details are locked and cannot be changed.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('opens a submitted image full screen when tapped',
      (tester) async {
    await _pump(tester, _approved());

    final frontLabel = find.text('CNIC Front');
    expect(frontLabel, findsOneWidget);

    // The thumbnail sits directly under its label inside the same column.
    final thumb = find
        .descendant(
          of: find.ancestor(of: frontLabel, matching: find.byType(Column)).first,
          matching: find.byType(GestureDetector),
        )
        .first;
    await tester.ensureVisible(thumb);
    await tester.pumpAndSettle();
    await tester.tap(thumb);
    await tester.pumpAndSettle();

    expect(find.byType(InteractiveViewer), findsOneWidget);
  });

  testWidgets('shows the profile photo, never a separate selfie prompt',
      (tester) async {
    await _pump(tester, _approved());

    expect(find.text('Profile Photo'), findsOneWidget);
    // The live-selfie wording is gone from the Ustaad's view entirely.
    expect(find.textContaining('Selfie'), findsNothing);
  });

  testWidgets('keeps a link to the accepted agreements', (tester) async {
    await _pump(tester, _approved());

    expect(find.text('Agreements'), findsWidgets);
    expect(find.byIcon(Icons.gavel_rounded), findsOneWidget);
  });

  testWidgets('shows a dash for anything that was never provided',
      (tester) async {
    await _pump(
      tester,
      WorkerProfileEntity(
        id: 'worker-2',
        userId: 'user-2',
        firstName: 'Sana',
        lastName: 'Iqbal',
        status: 'ACTIVE',
        verificationStatus: 'VERIFIED',
        availabilityStatus: AvailabilityStatus.offline,
        rating: 0,
        totalRatings: 0,
        skills: const [],
        stats: const WorkerStatsEntity(completedJobs: 0, activeJobs: 0),
        fullLegalName: 'Sana Iqbal',
        onboardingStatus: 'APPROVED',
      ),
    );

    // Absent values are shown as a dash rather than hidden, so the Ustaad can
    // see exactly what HandyGo holds on them.
    expect(find.text('—'), findsWidgets);
  });
}
