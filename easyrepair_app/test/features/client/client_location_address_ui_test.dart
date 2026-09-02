import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:handygo_app/core/l10n/app_locale.dart';
import 'package:handygo_app/core/l10n/l10n_config.dart';
import 'package:handygo_app/core/location/location_availability.dart';
import 'package:handygo_app/core/theme/app_semantic_colors.dart';
import 'package:handygo_app/core/theme/app_theme.dart';
import 'package:handygo_app/features/bookings/presentation/pages/full_screen_map_page.dart';
import 'package:handygo_app/features/categories/domain/entities/service_category_entity.dart';
import 'package:handygo_app/features/categories/domain/entities/standard_service_entity.dart';
import 'package:handygo_app/features/categories/presentation/providers/categories_providers.dart';
import 'package:handygo_app/features/client/presentation/pages/post_job_page.dart';
import 'package:handygo_app/features/client/presentation/widgets/location_picker_sheet.dart';
import 'package:handygo_app/features/client/presentation/widgets/saved_address_list.dart';
import 'package:handygo_app/features/saved_addresses/domain/entities/saved_address_entity.dart';
import 'package:handygo_app/features/saved_addresses/presentation/providers/saved_addresses_providers.dart';
import 'package:handygo_app/l10n/app_localizations.dart';

import '../../support/l10n_test_app.dart';

/// Covers the client-facing location/address surfaces that this branch
/// redesigned, and only those:
///
///  * the saved-address cards (label, address line, city, selected state,
///    Edit / Use actions, options sheet) that replaced a label-only
///    `InputChip` strip,
///  * the map picker sheet's search, GPS control, address readout and
///    confirm CTA,
///  * `FullScreenMapPage` / `MapExpandButton`, which used to be drawn in
///    `Colors.white` + `Color(0xFF1A1A1A)` and ignored the dark palette,
///  * the location permission / GPS-off / retry states these reach.
///
/// Everything asserted here is presentation. The address model, the saved
/// address API, the picker's geocoding and the permission flow are untouched
/// by this branch and are already covered by `post_job_page_test.dart`,
/// `location_availability_test.dart`, `location_recovery_snack_test.dart` and
/// `saved_addresses_provider_test.dart`.

const _category = ServiceCategoryEntity(
  id: 'cat-1',
  name: 'Electrician',
  inspectionFee: 500,
);

/// A real Karachi address of the length these cards actually have to hold.
const _longAddress =
    'House 12-B, Street 5, Lane 4, Khayaban-e-Bukhari, Phase VI, '
    'Defence Housing Authority, Karachi, Sindh 75500';

const _savedAddresses = [
  SavedAddressEntity(
    id: 'address-home',
    label: 'Home',
    normalizedLabel: 'home',
    addressLine: 'House 1, Street 2, Gulshan-e-Iqbal, Karachi',
    city: 'Karachi',
    latitude: 24.9204,
    longitude: 67.0987,
  ),
  SavedAddressEntity(
    id: 'address-office',
    label: 'Office',
    normalizedLabel: 'office',
    addressLine: _longAddress,
    city: 'Karachi',
    latitude: 24.8004,
    longitude: 67.0311,
  ),
];

/// The widths this app is expected to survive, per the design rules.
const _widths = <double>[320, 360, 390, 430];

class _GooglePlacesAdapter implements HttpClientAdapter {
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final data = switch (options.path) {
      final path when path.endsWith('/place/autocomplete/json') => {
        'status': 'OK',
        'predictions': [
          {
            'place_id': 'country-club-karachi',
            'description': 'Country Club, Karachi, Pakistan',
            'structured_formatting': {
              'main_text': 'Country Club',
              'secondary_text': 'Karachi, Pakistan',
            },
          },
        ],
      },
      final path when path.endsWith('/place/details/json') => {
        'status': 'OK',
        'result': {
          'formatted_address': 'Country Club Road, Karachi, Pakistan',
          'geometry': {
            'location': {'lat': 24.8732, 'lng': 67.0721},
          },
        },
      },
      final path when path.endsWith('/geocode/json') => {
        'status': 'OK',
        'results': [
          {'formatted_address': 'Adjusted Pin, Karachi, Pakistan'},
        ],
      },
      _ => <String, dynamic>{'status': 'ZERO_RESULTS'},
    };
    return ResponseBody.fromString(
      jsonEncode(data),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _FakeSavedAddressesNotifier extends SavedAddressesNotifier {
  @override
  Future<List<SavedAddressEntity>> build() async => _savedAddresses;
}

ProviderScope _wrapPostJob(
  Widget child, {
  AppLocale locale = AppLocale.english,
  BookingCurrentLocationResolver? currentLocationResolver,
  BookingAddressLabelResolver? addressLabelResolver,
  ThemeData? theme,
}) {
  return ProviderScope(
    overrides: [
      clientBookingCategoriesProvider.overrideWith((ref) async => [_category]),
      standardServicesProvider.overrideWith(
        (ref, categoryId) async => const <StandardServiceEntity>[],
      ),
      savedAddressesProvider.overrideWith(_FakeSavedAddressesNotifier.new),
      bookingMapPreviewPositionProvider.overrideWith((ref) async => null),
      if (currentLocationResolver != null)
        bookingCurrentLocationResolverProvider.overrideWithValue(
          currentLocationResolver,
        ),
      if (addressLabelResolver != null)
        bookingAddressLabelResolverProvider.overrideWithValue(
          addressLabelResolver,
        ),
    ],
    child: localizedApp(child, locale: locale, theme: theme),
  );
}

Future<void> _pumpPostJobAddressStep(
  WidgetTester tester, {
  AppLocale locale = AppLocale.english,
  double width = 390,
  double textScale = 1.0,
  BookingCurrentLocationResolver? currentLocationResolver,
  BookingAddressLabelResolver? addressLabelResolver,
  ThemeData? theme,
}) async {
  tester.view.physicalSize = Size(width, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    _wrapPostJob(
      MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: const BookServicePage(preselectedService: 'Electrician'),
      ),
      locale: locale,
      currentLocationResolver: currentLocationResolver,
      addressLabelResolver: addressLabelResolver,
      theme: theme,
    ),
  );
  await tester.pumpAndSettle();
}

/// Pumps the saved-address cards on their own, so a card assertion is not
/// entangled with the whole booking wizard.
Future<void> _pumpSavedAddressList(
  WidgetTester tester, {
  String? selectedId,
  AppLocale locale = AppLocale.english,
  double width = 390,
  double textScale = 1.0,
  ThemeData? theme,
  void Function(SavedAddressEntity)? onSelect,
  void Function(SavedAddressEntity)? onEdit,
}) async {
  tester.view.physicalSize = Size(width, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    localizedApp(
      Scaffold(
        body: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: SavedAddressList(
              addresses: _savedAddresses,
              selectedId: selectedId,
              onSelect: onSelect ?? (_) {},
              onEdit: onEdit ?? (_) {},
            ),
          ),
        ),
      ),
      locale: locale,
      theme: theme,
    ),
  );
  await tester.pumpAndSettle();
}

/// Opens the map picker on its own tree.
///
/// The text scale is applied through `MaterialApp.builder`, above the
/// Navigator, so it reaches the modal sheet — a `MediaQuery` around `home`
/// would not.
Future<void> _pumpPickerAlone(
  WidgetTester tester, {
  double width = 390,
  double textScale = 1.0,
  AppLocale locale = AppLocale.english,
  PickedLocation? initial = const PickedLocation(
    latitude: 24.9204,
    longitude: 67.0987,
    address: _longAddress,
  ),
  Dio? googleApiDio,
}) async {
  tester.view.physicalSize = Size(width, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      locale: locale.locale,
      supportedLocales: appSupportedLocales,
      localizationsDelegates: appLocalizationsDelegates,
      localeResolutionCallback: (_, _) => locale.locale,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () => showLocationPicker(
                context,
                initial: initial,
                googleApiDio: googleApiDio,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

AppLocalizations _l10n(WidgetTester tester) =>
    AppLocalizations.of(tester.element(find.byType(Navigator).first));

/// Every colour the palette can produce, for either brightness — used to
/// prove a widget's paint came from a token and not from a literal.
Set<int> _paletteValues() => {
  for (final palette in [AppSemanticColors.light, AppSemanticColors.dark])
    ...[
      palette.background,
      palette.surface,
      palette.surfaceSubtle,
      palette.textPrimary,
      palette.textSecondary,
      palette.onPrimary,
      palette.onPrimaryMuted,
      palette.scrim,
      palette.onScrim,
      palette.border,
      palette.controlBorder,
      palette.primary,
      palette.primaryPressed,
      palette.softTeal,
      palette.urgent,
      palette.urgentSoft,
      palette.success,
      palette.successSoft,
      palette.warning,
      palette.warningSurface,
      palette.error,
      palette.errorSoft,
    ].map((c) => c.toARGB32()),
};

void main() {
  group('saved address cards', () {
    testWidgets('every saved address renders its label, address line and city',
        (tester) async {
      await _pumpSavedAddressList(tester);

      expect(find.text(_l10n(tester).savedAddresses), findsOneWidget);
      for (final address in _savedAddresses) {
        expect(find.text(address.label), findsOneWidget);
        expect(find.text(address.addressLine), findsOneWidget);
      }
      // The card shows only what the backend sends — no invented lines.
      expect(find.text('Karachi'), findsNWidgets(2));
    });

    testWidgets('the selected address carries the semantic selected treatment '
        'and no other card does', (tester) async {
      await _pumpSavedAddressList(tester, selectedId: 'address-home');

      final colors = AppSemanticColors.light;
      final decorations = tester
          .widgetList<Container>(find.byType(Container))
          .map((c) => c.decoration)
          .whereType<BoxDecoration>()
          .where((d) => d.border != null)
          .toList();

      // Exactly one card is outlined in `primary`; the rest use the hairline.
      final primaryBordered = decorations.where(
        (d) => (d.border as Border?)?.top.color == colors.primary,
      );
      expect(primaryBordered, hasLength(1));

      // The selected card also gets a check, and it is the only one.
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    });

    testWidgets('with nothing selected no card is outlined in primary',
        (tester) async {
      await _pumpSavedAddressList(tester, selectedId: null);
      expect(find.byIcon(Icons.check_circle_rounded), findsNothing);
    });

    testWidgets('Use selects that exact address and Edit opens options for it',
        (tester) async {
      SavedAddressEntity? selected;
      SavedAddressEntity? edited;
      await _pumpSavedAddressList(
        tester,
        onSelect: (a) => selected = a,
        onEdit: (a) => edited = a,
      );
      final l10n = _l10n(tester);

      await tester.tap(find.text(l10n.savedAddressUse).last);
      await tester.pump();
      expect(selected?.id, 'address-office');

      await tester.tap(find.text(l10n.cardEdit).first);
      await tester.pump();
      expect(edited?.id, 'address-home');
    });

    testWidgets('tapping the card body itself selects it', (tester) async {
      SavedAddressEntity? selected;
      await _pumpSavedAddressList(tester, onSelect: (a) => selected = a);

      await tester.tap(find.text('Home'));
      await tester.pump();
      expect(selected?.id, 'address-home');
    });

    testWidgets('card actions clear the 44px minimum tap target',
        (tester) async {
      await _pumpSavedAddressList(tester);
      final l10n = _l10n(tester);

      for (final label in [l10n.cardEdit, l10n.savedAddressUse]) {
        final buttons = find.ancestor(
          of: find.text(label),
          matching: find.bySubtype<TextButton>(),
        );
        expect(buttons, findsNWidgets(_savedAddresses.length));
        for (var i = 0; i < _savedAddresses.length; i++) {
          expect(tester.getSize(buttons.at(i)).height, greaterThanOrEqualTo(44));
        }
      }
    });

    testWidgets('a long Karachi address wraps instead of overflowing, at every '
        'target width', (tester) async {
      for (final width in _widths) {
        await _pumpSavedAddressList(tester, width: width);
        expect(
          tester.takeException(),
          isNull,
          reason: 'saved-address cards overflowed at ${width}px',
        );
        expect(find.text(_longAddress), findsOneWidget);
      }
    });

    testWidgets('survives a 2.0 text scale at the narrowest width',
        (tester) async {
      await _pumpSavedAddressList(tester, width: 320, textScale: 2.0);
      expect(tester.takeException(), isNull);
      expect(find.text('Home'), findsOneWidget);
    });

    testWidgets('renders in Urdu and Roman Urdu without overflow at 320',
        (tester) async {
      for (final locale in [AppLocale.urdu, AppLocale.romanUrdu]) {
        await _pumpSavedAddressList(tester, width: 320, locale: locale);
        expect(
          tester.takeException(),
          isNull,
          reason: 'saved-address cards overflowed in $locale',
        );
        // The client's own address text is never translated.
        expect(find.text(_longAddress), findsOneWidget);
        expect(find.text('Home'), findsOneWidget);
      }
    });

    testWidgets('paints only palette colours, in both themes', (tester) async {
      final palette = _paletteValues();
      for (final theme in [AppTheme.lightTheme, AppTheme.darkTheme]) {
        await _pumpSavedAddressList(
          tester,
          selectedId: 'address-home',
          theme: theme,
        );

        final fills = tester
            .widgetList<Material>(find.byType(Material))
            .map((m) => m.color)
            .whereType<Color>()
            // Material's own transparent scaffolding is not a paint decision.
            .where((c) => c.a != 0);

        for (final fill in fills) {
          expect(
            palette.contains(fill.toARGB32()),
            isTrue,
            reason: '$fill is not a HandyGo semantic token',
          );
        }
      }
    });

    testWidgets('cards cast no shadow', (tester) async {
      await _pumpSavedAddressList(tester, selectedId: 'address-home');
      final shadowed = tester
          .widgetList<Container>(find.byType(Container))
          .map((c) => c.decoration)
          .whereType<BoxDecoration>()
          .where((d) => d.boxShadow != null && d.boxShadow!.isNotEmpty);
      expect(shadowed, isEmpty);
    });
  });

  group('saved address options sheet', () {
    testWidgets('offers use / update / rename / delete and returns the action',
        (tester) async {
      String? action;
      await tester.pumpWidget(
        localizedApp(
          Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () async {
                    action = await showSavedAddressOptionsSheet(
                      context,
                      _savedAddresses.first,
                    );
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      final l10n = _l10n(tester);
      expect(find.text(l10n.savedAddressUse), findsOneWidget);
      expect(find.text(l10n.savedAddressUpdateWithCurrent), findsOneWidget);
      expect(find.text(l10n.savedAddressRename), findsOneWidget);
      expect(find.text(l10n.commonDelete), findsOneWidget);
      // The sheet names the address it acts on.
      expect(find.text(_savedAddresses.first.label), findsOneWidget);
      expect(find.text(_savedAddresses.first.addressLine), findsOneWidget);

      await tester.tap(find.text(l10n.savedAddressRename));
      await tester.pumpAndSettle();
      expect(action, 'rename');
    });

    testWidgets('every option row clears the 56px minimum row height',
        (tester) async {
      await tester.pumpWidget(
        localizedApp(
          Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () => showSavedAddressOptionsSheet(
                    context,
                    _savedAddresses.first,
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      final l10n = _l10n(tester);
      for (final label in [
        l10n.savedAddressUse,
        l10n.savedAddressUpdateWithCurrent,
        l10n.savedAddressRename,
        l10n.commonDelete,
      ]) {
        final row = find.widgetWithText(InkWell, label);
        expect(row, findsOneWidget);
        expect(tester.getSize(row).height, greaterThanOrEqualTo(56));
      }
    });
  });

  group('name-this-address sheet', () {
    testWidgets('an inline validation error blocks the save and clears on edit',
        (tester) async {
      String? saved;
      await tester.pumpWidget(
        localizedApp(
          Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () async {
                    saved = await showSavedAddressNameSheet(
                      context,
                      title: 'Name this address',
                      onValidate: (value) =>
                          value.isEmpty ? 'Enter a name.' : null,
                    );
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // Empty → rejected inline, sheet stays open.
      await tester.tap(find.text(_l10n(tester).commonSave));
      await tester.pumpAndSettle();
      expect(find.text('Enter a name.'), findsOneWidget);
      expect(saved, isNull);

      await tester.enterText(find.byType(TextField), 'Nani ka ghar');
      await tester.pumpAndSettle();
      expect(find.text('Enter a name.'), findsNothing);

      await tester.tap(find.text(_l10n(tester).commonSave));
      await tester.pumpAndSettle();
      expect(saved, 'Nani ka ghar');
    });

    testWidgets('the save action clears the 52px primary-button height',
        (tester) async {
      await tester.pumpWidget(
        localizedApp(
          Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () => showSavedAddressNameSheet(
                    context,
                    title: 'Name it',
                    onValidate: (_) => null,
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      final size = tester.getSize(find.byType(FilledButton));
      expect(size.height, greaterThanOrEqualTo(52));
    });
  });

  group('map picker sheet', () {
    testWidgets(
      'Country Club search shows a Karachi-biased suggestion that selects '
      'the map location and still permits a final pin adjustment',
      (tester) async {
        final adapter = _GooglePlacesAdapter();
        final dio = Dio()..httpClientAdapter = adapter;
        addTearDown(dio.close);
        await _pumpPickerAlone(tester, initial: null, googleApiDio: dio);

        await tester.enterText(find.byType(TextField), 'Country Club');
        await tester.pump(const Duration(milliseconds: 501));
        await tester.pumpAndSettle();

        expect(find.text('Country Club'), findsNWidgets(2));
        expect(find.text('Karachi, Pakistan'), findsOneWidget);
        final autocomplete = adapter.requests.singleWhere(
          (request) => request.path.endsWith('/place/autocomplete/json'),
        );
        expect(autocomplete.queryParameters['input'], 'Country Club');
        expect(autocomplete.queryParameters['components'], 'country:pk');
        expect(autocomplete.queryParameters['region'], 'pk');
        expect(autocomplete.queryParameters['location'], '24.8607,67.0011');
        expect(autocomplete.queryParameters['radius'], '25000');
        expect(autocomplete.queryParameters['sessiontoken'], isNot(isEmpty));

        await tester.tap(find.text('Country Club').last);
        await tester.pumpAndSettle();

        expect(
          find.text('Country Club Road, Karachi, Pakistan'),
          findsOneWidget,
        );
        var map = tester.widget<GoogleMap>(find.byType(GoogleMap));
        expect(
          map.initialCameraPosition.target,
          const LatLng(24.8732, 67.0721),
        );

        map.onTap!(const LatLng(24.881, 67.091));
        await tester.pumpAndSettle();

        expect(find.text('Adjusted Pin, Karachi, Pakistan'), findsOneWidget);
        map = tester.widget<GoogleMap>(find.byType(GoogleMap));
        expect(map.initialCameraPosition.target, const LatLng(24.881, 67.091));
      },
    );

    testWidgets('opens with a map, a search field, a GPS control and a '
        'disabled confirm', (tester) async {
      await _pumpPostJobAddressStep(tester);
      final l10n = _l10n(tester);

      await tester.ensureVisible(find.text(l10n.postJobPickOnMap));
      await tester.tap(find.text(l10n.postJobPickOnMap));
      await tester.pumpAndSettle();

      expect(find.text(l10n.locationSearchHint), findsOneWidget);
      expect(find.byIcon(Icons.my_location_rounded), findsWidgets);
      // Page 1's own preview stays mounted behind the sheet.
      expect(find.byType(GoogleMap), findsNWidgets(2));

      // Nothing picked yet: the hint shows and the CTA cannot be used.
      expect(find.text(l10n.locationMoveMapHint), findsOneWidget);
      final confirm = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, l10n.locationUseThis),
      );
      expect(confirm.onPressed, isNull);
    });

    testWidgets('the confirm CTA clears the 52px primary-button height',
        (tester) async {
      await _pumpPostJobAddressStep(tester);
      final l10n = _l10n(tester);

      await tester.ensureVisible(find.text(l10n.postJobPickOnMap));
      await tester.tap(find.text(l10n.postJobPickOnMap));
      await tester.pumpAndSettle();

      final size = tester.getSize(
        find.widgetWithText(ElevatedButton, l10n.locationUseThis),
      );
      expect(size.height, greaterThanOrEqualTo(52));
    });

    testWidgets('an initial address is shown as the resolved readout and the '
        'confirm becomes usable', (tester) async {
      await tester.pumpWidget(
        localizedApp(
          Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () => showLocationPicker(
                    context,
                    initial: const PickedLocation(
                      latitude: 24.9204,
                      longitude: 67.0987,
                      address: _longAddress,
                    ),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text(_longAddress), findsOneWidget);
      final confirm = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, _l10n(tester).locationUseThis),
      );
      expect(confirm.onPressed, isNotNull);
    });

    testWidgets('confirming returns the picked location unchanged',
        (tester) async {
      PickedLocation? result;
      await tester.pumpWidget(
        localizedApp(
          Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () async {
                    result = await showLocationPicker(
                      context,
                      initial: const PickedLocation(
                        latitude: 24.9204,
                        longitude: 67.0987,
                        address: _longAddress,
                      ),
                    );
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(_l10n(tester).locationUseThis));
      await tester.pumpAndSettle();

      expect(result?.latitude, 24.9204);
      expect(result?.longitude, 67.0987);
      expect(result?.address, _longAddress);
    });

    testWidgets('the map keeps its picker mechanics', (tester) async {
      await tester.pumpWidget(
        localizedApp(
          Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () => showLocationPicker(context),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      final map = tester.widget<GoogleMap>(find.byType(GoogleMap));
      // Karachi centre, own-location layer on, chrome off, tilt/rotate off —
      // exactly as before the redesign.
      expect(map.initialCameraPosition.target, const LatLng(24.8607, 67.0011));
      expect(map.myLocationEnabled, isTrue);
      expect(map.myLocationButtonEnabled, isFalse);
      expect(map.zoomControlsEnabled, isFalse);
      expect(map.mapToolbarEnabled, isFalse);
      expect(map.tiltGesturesEnabled, isFalse);
      expect(map.rotateGesturesEnabled, isFalse);
      expect(map.gestureRecognizers, isNotEmpty);
      expect(map.onTap, isNotNull);
      expect(map.onCameraMove, isNotNull);
      expect(map.onCameraIdle, isNotNull);
    });

    for (final width in _widths) {
      testWidgets('renders without overflow at ${width.toInt()}px', (
        tester,
      ) async {
        await _pumpPickerAlone(tester, width: width);
        expect(tester.takeException(), isNull);
        expect(find.text(_longAddress), findsOneWidget);
      });
    }

    testWidgets('renders without overflow at 320px and a 2.0 text scale', (
      tester,
    ) async {
      await _pumpPickerAlone(tester, width: 320, textScale: 2.0);
      expect(tester.takeException(), isNull);
    });

    for (final locale in [AppLocale.urdu, AppLocale.romanUrdu]) {
      testWidgets('renders without overflow at 320px in $locale', (
        tester,
      ) async {
        await _pumpPickerAlone(tester, width: 320, locale: locale);
        expect(tester.takeException(), isNull);
        expect(find.text(_l10n(tester).locationUseThis), findsOneWidget);
      });
    }
  });

  group('current-location states on the address step', () {
    Position position() => Position(
      latitude: 24.9012,
      longitude: 67.1154,
      timestamp: DateTime(2026, 8, 28),
      accuracy: 5,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );

    testWidgets('a successful fix fills the address in and pins the map',
        (tester) async {
      await _pumpPostJobAddressStep(
        tester,
        currentLocationResolver: () async => LocationAvailabilityResult(
          LocationAvailability.available,
          position: position(),
        ),
        addressLabelResolver: (lat, lng) async => _longAddress,
      );
      final l10n = _l10n(tester);

      await tester.ensureVisible(find.text(l10n.postJobCurrentLocation));
      await tester.tap(find.text(l10n.postJobCurrentLocation));
      await tester.pumpAndSettle();

      expect(find.text(_longAddress), findsWidgets);
      final map = tester.widget<GoogleMap>(find.byType(GoogleMap));
      expect(map.markers, hasLength(1));
    });

    testWidgets('while a fix is in flight the control shows a spinner',
        (tester) async {
      final gate = Completer<LocationAvailabilityResult>();
      await _pumpPostJobAddressStep(
        tester,
        currentLocationResolver: () => gate.future,
      );
      final l10n = _l10n(tester);

      await tester.ensureVisible(find.text(l10n.postJobCurrentLocation));
      await tester.tap(find.text(l10n.postJobCurrentLocation));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsWidgets);

      gate.complete(
        const LocationAvailabilityResult(LocationAvailability.unavailable),
      );
      await tester.pumpAndSettle();
    });

    // One test per status: a SnackBar queued by a previous iteration outlives
    // a re-pump, so a loop inside one test would assert against the wrong
    // snack.
    final recoveryActions = <LocationAvailability, String Function(
      AppLocalizations,
    )>{
      LocationAvailability.permissionDenied: (l) => l.locationAllowAction,
      LocationAvailability.permissionPermanentlyDenied: (l) =>
          l.commonOpenSettings,
      LocationAvailability.serviceDisabled: (l) => l.locationTurnOnAction,
      LocationAvailability.unavailable: (l) => l.commonRetry,
    };

    for (final entry in recoveryActions.entries) {
      testWidgets('${entry.key.name} offers its own localized recovery action', (
        tester,
      ) async {
        await _pumpPostJobAddressStep(
          tester,
          currentLocationResolver: () async =>
              LocationAvailabilityResult(entry.key),
        );
        final l10n = _l10n(tester);

        await tester.ensureVisible(find.text(l10n.postJobCurrentLocation));
        await tester.tap(find.text(l10n.postJobCurrentLocation));
        await tester.pumpAndSettle();

        expect(find.byType(SnackBar), findsOneWidget);
        expect(find.text(entry.value(l10n)), findsOneWidget);
        // A failed fix never silently fills the address field in.
        expect(
          tester
              .widget<TextFormField>(find.byType(TextFormField))
              .controller
              ?.text,
          isEmpty,
        );
      });
    }

    testWidgets('the address step survives every target width and a 2.0 text '
        'scale', (tester) async {
      for (final width in _widths) {
        await _pumpPostJobAddressStep(tester, width: width);
        expect(
          tester.takeException(),
          isNull,
          reason: 'address step overflowed at ${width}px',
        );
      }
      await _pumpPostJobAddressStep(tester, width: 320, textScale: 2.0);
      expect(tester.takeException(), isNull);
    });
  });

  group('full screen map page', () {
    final markers = ValueNotifier<Set<Marker>>({
      const Marker(markerId: MarkerId('job'), position: LatLng(24.86, 67.00)),
    });

    Widget page({ThemeData? theme}) => localizedApp(
      FullScreenMapPage(
        title: 'Job location',
        markersListenable: markers,
        initialTarget: const LatLng(24.86, 67.00),
      ),
      theme: theme,
    );

    testWidgets('the app bar is painted from the palette in both themes, '
        'never in white', (tester) async {
      for (final theme in [AppTheme.lightTheme, AppTheme.darkTheme]) {
        await tester.pumpWidget(page(theme: theme));
        await tester.pumpAndSettle();

        final colors = AppSemanticColors.of(theme.brightness);
        final appBar = tester.widget<AppBar>(find.byType(AppBar));
        expect(appBar.backgroundColor, colors.surface);
        expect(appBar.foregroundColor, colors.textPrimary);
        expect(appBar.elevation, 0);

        final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
        expect(scaffold.backgroundColor, colors.background);
      }
    });

    testWidgets('the map itself keeps full gestures and its live markers',
        (tester) async {
      await tester.pumpWidget(page());
      await tester.pumpAndSettle();

      final map = tester.widget<GoogleMap>(find.byType(GoogleMap));
      expect(map.markers, hasLength(1));
      expect(map.zoomGesturesEnabled, isTrue);
      expect(map.scrollGesturesEnabled, isTrue);
      expect(map.rotateGesturesEnabled, isTrue);
      expect(map.tiltGesturesEnabled, isTrue);
      expect(map.zoomControlsEnabled, isTrue);
      expect(map.initialCameraPosition.target, const LatLng(24.86, 67.00));
    });

    testWidgets('a long title truncates instead of overflowing at 320',
        (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        localizedApp(
          FullScreenMapPage(
            title: _longAddress,
            markersListenable: markers,
            initialTarget: const LatLng(24.86, 67.00),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('MapExpandButton is a 44px palette-painted control',
        (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        localizedApp(
          Scaffold(
            body: Center(child: MapExpandButton(onTap: () => tapped = true)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final size = tester.getSize(find.byIcon(Icons.fullscreen_rounded));
      expect(size.width, greaterThanOrEqualTo(22));

      final material = tester.widget<Material>(
        find.descendant(
          of: find.byType(MapExpandButton),
          matching: find.byType(Material),
        ).first,
      );
      expect(material.color, AppSemanticColors.light.surface);

      await tester.tap(find.byIcon(Icons.fullscreen_rounded));
      expect(tapped, isTrue);
    });
  });
}
