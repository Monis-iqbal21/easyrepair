import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handygo_app/core/l10n/app_locale.dart';
import 'package:handygo_app/core/l10n/l10n_extensions.dart';
import 'package:handygo_app/core/router/app_router.dart';
import 'package:handygo_app/features/auth/domain/entities/user_entity.dart';
import 'package:handygo_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:handygo_app/features/categories/data/datasources/categories_remote_datasource.dart';
import 'package:handygo_app/features/categories/presentation/providers/categories_providers.dart';
import 'package:handygo_app/features/client/domain/entities/customer_agreement_entity.dart';
import 'package:handygo_app/features/client/presentation/pages/client_home_page.dart';
import 'package:handygo_app/features/client/presentation/pages/post_job_page.dart';
import 'package:handygo_app/features/client/presentation/providers/customer_agreement_providers.dart';
import 'package:handygo_app/features/notifications/presentation/providers/notification_providers.dart';
import 'package:handygo_app/features/saved_addresses/domain/entities/saved_address_entity.dart';
import 'package:handygo_app/features/saved_addresses/presentation/providers/saved_addresses_providers.dart';

import '../../support/l10n_test_app.dart';

// Production GET /categories on 2026-09-03 succeeded with these 11 categories
// and NO Appliance(s) Repair row. A successful, nonempty list does not use
// offline stubs. Retain the response fields consumed by the category parser.
const _productionNames = [
  'AC Technician',
  'Carpenter',
  'Car Wash',
  'Cleaner',
  'Cleaning',
  'Electrician',
  'Gardener',
  'Handyman',
  'Painter',
  'Pest Control',
  'Plumber',
];
const _activeNames = ['AC Technician', 'Carpenter', 'Electrician', 'Plumber'];
const _applianceId = 'fixture-appliance-id';
const _appliance = <String, dynamic>{
  'id': _applianceId,
  'name': 'Appliances Repair',
  'description':
      'Washing machine, fridge, microwave & home appliance diagnosis and repair',
  'iconUrl': null,
  'inspectionFee': 500,
  'inspectionOnly': false,
  'soleLane': 'BIDDING',
  'availabilityStatus': 'ACTIVE',
};

class _CategoryApi implements HttpClientAdapter {
  bool restored = false;
  String applianceName = 'Appliances Repair';
  int requests = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    expect(options.path, '/categories');
    requests++;
    return ResponseBody.fromString(
      jsonEncode({
        'success': true,
        'data': [
          for (final name in _productionNames)
            {
              'id': 'fixture-$name',
              'name': name,
              'description': null,
              'iconUrl': null,
              'inspectionFee': _activeNames.contains(name) ? 500 : null,
              'inspectionOnly': false,
              'soleLane': null,
              'availabilityStatus': _activeNames.contains(name)
                  ? 'ACTIVE'
                  : 'SOON',
            },
          if (restored) {..._appliance, 'name': applianceName},
        ],
        'message': '',
      }),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _Client extends AuthStateNotifier {
  @override
  Future<UserEntity?> build() async => const UserEntity(
    id: 'client',
    phone: '+923001234567',
    role: 'CLIENT',
    firstName: 'Sara',
    lastName: 'Khan',
  );
}

class _Addresses extends SavedAddressesNotifier {
  @override
  Future<List<SavedAddressEntity>> build() async => const [
    SavedAddressEntity(
      id: 'home',
      label: 'Home',
      normalizedLabel: 'home',
      addressLine: 'House 12, Street 5, Karachi',
      city: 'Karachi',
      latitude: 24.86,
      longitude: 67.01,
    ),
  ];
}

const _acceptedTerms = CustomerAgreementStatusEntity(
  acceptanceRequired: false,
  agreement: CustomerAgreementEntity(
    documentType: kCustomerTermsDocumentType,
    title: 'Customer terms',
    version: '1.0',
    agreementLocale: 'ur_Latn',
    sourceHash: 'fixture',
    contentText: 'fixture',
    legalLanguageNoticeRequired: false,
    requestedAppLocale: 'ur_Latn',
  ),
  existingAcceptance: null,
);

Future<ProviderContainer> _pumpHome(
  WidgetTester tester,
  _CategoryApi api,
) async {
  tester.view.physicalSize = const Size(390, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final dio = Dio()..httpClientAdapter = api;
  final container = ProviderContainer(
    overrides: [
      authStateProvider.overrideWith(_Client.new),
      requiredCustomerAgreementProvider.overrideWith(
        (ref) async => _acceptedTerms,
      ),
      currentClientAreaProvider.overrideWith((ref) async => 'Karachi'),
      unreadNotificationCountProvider.overrideWith((ref) async => 0),
      savedAddressesProvider.overrideWith(_Addresses.new),
      bookingMapPreviewPositionProvider.overrideWith((ref) async => null),
      categoriesRemoteDataSourceProvider.overrideWithValue(
        CategoriesRemoteDataSourceImpl(dio),
      ),
    ],
  );
  addTearDown(container.dispose);
  await container.read(authStateProvider.future);
  final router = container.read(routerProvider);
  await container.read(requiredCustomerAgreementProvider.future);
  addTearDown(router.dispose);
  router.go('/client/home');
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: localizedRouterApp(router, locale: AppLocale.romanUrdu),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

Future<void> _openLanes(WidgetTester tester) async {
  await tester.tap(find.text('Home'));
  await tester.pump();
  await tester.ensureVisible(find.text('Aage'));
  await tester.tap(find.text('Aage'));
  await tester.pumpAndSettle();
}

void _expectOnlyBidding(WidgetTester tester) {
  final bidding = find.byKey(const ValueKey('booking-lane-bidding'));
  expect(bidding, findsOneWidget);
  expect(tester.widget<Semantics>(bidding).properties.enabled, isTrue);
  expect(find.text('Custom kaam'), findsOneWidget);
  expect(find.byKey(const ValueKey('booking-lane-standard')), findsNothing);
  expect(find.byKey(const ValueKey('booking-lane-inspection')), findsNothing);
  expect(find.text('Fixed price'), findsNothing);
  expect(find.text('Inspection'), findsNothing);
}

void main() {
  testWidgets(
    'real Home to router to API to lanes carries ID and shows one card',
    (tester) async {
      final api = _CategoryApi()..restored = true;
      await _pumpHome(tester, api);
      final home = tester.element(find.byType(ClientHomePage));
      final title = home.l10n.serviceAppliancesRepair;
      await tester.ensureVisible(find.text(title));
      await tester.tap(find.text(title));
      await tester.pumpAndSettle();
      final page = tester.widget<BookServicePage>(find.byType(BookServicePage));
      expect(page.preselectedCategoryId, _applianceId);
      expect(page.preselectedService, 'Appliances Repair');
      await _openLanes(tester);
      _expectOnlyBidding(tester);
      expect(api.requests, 1);
    },
  );

  testWidgets(
    'production missing-row response gives retry; restored row recovers',
    (tester) async {
      final api = _CategoryApi();
      await _pumpHome(tester, api);
      final title = tester
          .element(find.byType(ClientHomePage))
          .l10n
          .serviceAppliancesRepair;
      await tester.ensureVisible(find.text(title));
      await tester.tap(find.text(title));
      await tester.pumpAndSettle();
      await _openLanes(tester);
      expect(
        find.text(
          'Services load nahi ho sakin. Wapas jaa kar dobara koshish karein.',
        ),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('booking-lane-bidding')), findsNothing);
      api.restored = true;
      await tester.tap(find.text('Dobara koshish karein'));
      await tester.pumpAndSettle();
      _expectOnlyBidding(tester);
      expect(api.requests, 2);
    },
  );

  testWidgets(
    'ID survives API singular/spacing rename and localized route label',
    (tester) async {
      final api = _CategoryApi()..restored = true;
      final container = await _pumpHome(tester, api);
      api.applianceName = '  Appliance Repair  ';
      container.invalidate(allCategoriesProvider);
      await tester.pumpAndSettle();
      container
          .read(routerProvider)
          .push(
            Uri(
              path: '/client/post-job',
              queryParameters: {
                'categoryId': _applianceId,
                'service': 'گھریلو آلات کی مرمت',
              },
            ).toString(),
          );
      await tester.pumpAndSettle();
      await _openLanes(tester);
      _expectOnlyBidding(tester);
    },
  );
}
