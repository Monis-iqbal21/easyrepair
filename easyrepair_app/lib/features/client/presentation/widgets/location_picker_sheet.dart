import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show Factory, visibleForTesting;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../../core/l10n/l10n_extensions.dart';
import '../../../../core/location/location_availability.dart';
import '../../../../core/location/location_recovery_snack.dart';
import '../../../../core/services/geocoding_service.dart';
import '../../../../core/theme/app_semantic_colors.dart';

// ── API key (dart-define) ──────────────────────────────────────────────────────
const _kMapsApiKey = String.fromEnvironment('GOOGLE_MAPS_API_KEY');

// ── Karachi reference ─────────────────────────────────────────────────────────
const _kKarachiCenter = LatLng(24.8607, 67.0011);
const _kKarachiRadiusM = 55000.0; // 55 km

// ── Shape ─────────────────────────────────────────────────────────────────────
// The same values Choose Ustaad and the bidding cards use, so this sheet reads
// as one surface with the rest of the redesigned client UI. Colours are never
// declared here — every one comes from `context.semanticColors`.
const double _rCard = 16;
const double _rButton = 14;

/// Minimum height of the sheet's primary action, per the prototype.
const double _hAction = 52;

/// Minimum height of a tappable row (a search-result line, the GPS control).
const double _hRow = 44;

// ── Result model ──────────────────────────────────────────────────────────────

class PickedLocation {
  final double latitude;
  final double longitude;
  final String address;

  const PickedLocation({
    required this.latitude,
    required this.longitude,
    required this.address,
  });
}

// ── Places prediction model ───────────────────────────────────────────────────

class _PlacePrediction {
  final String placeId;
  final String mainText;
  final String secondaryText;

  const _PlacePrediction({
    required this.placeId,
    required this.mainText,
    required this.secondaryText,
  });
}

// ── Sheet entry point ─────────────────────────────────────────────────────────

/// Opens from the bottom as a full-height modal.
/// Returns a [PickedLocation] when the user confirms, or null if dismissed.
Future<PickedLocation?> showLocationPicker(
  BuildContext context, {
  PickedLocation? initial,
  @visibleForTesting Dio? googleApiDio,
}) {
  return showModalBottomSheet<PickedLocation>(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.semanticColors.surface,
    // The sheet owns its own rounded top and clips to it, so the child no
    // longer has to paint a transparent-background trick to get the corners.
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    clipBehavior: Clip.antiAlias,
    builder: (_) =>
        _LocationPickerSheet(initial: initial, googleApiDio: googleApiDio),
  );
}

// ── Sheet widget ──────────────────────────────────────────────────────────────

class _LocationPickerSheet extends StatefulWidget {
  final PickedLocation? initial;
  final Dio? googleApiDio;

  const _LocationPickerSheet({this.initial, this.googleApiDio});

  @override
  State<_LocationPickerSheet> createState() => _LocationPickerSheetState();
}

class _LocationPickerSheetState extends State<_LocationPickerSheet> {
  AppSemanticColors get _colors => context.semanticColors;

  GoogleMapController? _mapCtrl;

  LatLng? _picked;
  String _addressLabel = '';
  bool _reverseGeocoding = false;
  LatLng? _cameraCenter;

  /// Prevents [_onCameraIdle] from re-geocoding after a programmatic move.
  bool _skipNextIdle = false;

  /// True while the user is actively dragging the map.
  bool _isDragging = false;

  /// Debounces reverse-geocode calls until the map has been idle for a beat —
  /// cancelled on every new move/idle so a quick series of drags only ever
  /// spends one API call, on the final settled position.
  Timer? _geocodeDebounce;

  /// Bumped on every new reverse-geocode attempt. A response is only applied
  /// if it's still the latest one requested — guards against a slow/
  /// out-of-order network response from an earlier position overwriting the
  /// address for a position the user has since moved to.
  int _geocodeGeneration = 0;

  // ── Search ─────────────────────────────────────────────────────────────────
  final _searchCtrl = TextEditingController();
  bool _searching = false;
  List<_PlacePrediction> _predictions = [];
  Timer? _debounce;
  int _autocompleteGeneration = 0;
  String? _lastCompletedQuery;
  bool _searchFailed = false;
  late String _placesSessionToken;

  // ── GPS ────────────────────────────────────────────────────────────────────
  bool _gpsLoading = false;

  // ── Bare Dio for Google APIs (no auth interceptors) ────────────────────────
  late final Dio _geoDio;
  late final bool _ownsGeoDio;

  // ── Init / dispose ─────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _ownsGeoDio = widget.googleApiDio == null;
    _geoDio =
        widget.googleApiDio ??
        Dio(
          BaseOptions(
            connectTimeout: const Duration(seconds: 8),
            receiveTimeout: const Duration(seconds: 8),
          ),
        );
    _placesSessionToken = _newPlacesSessionToken();
    if (widget.initial != null) {
      _picked = LatLng(widget.initial!.latitude, widget.initial!.longitude);
      _addressLabel = widget.initial!.address;
      _cameraCenter = _picked;
      // Address is already known — skip the first onCameraIdle geocode.
      _skipNextIdle = true;
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _debounce?.cancel();
    _geocodeDebounce?.cancel();
    _mapCtrl?.dispose();
    if (_ownsGeoDio) _geoDio.close(force: true);
    super.dispose();
  }

  String _newPlacesSessionToken() =>
      '${DateTime.now().microsecondsSinceEpoch}-${identityHashCode(this)}';

  // ── Karachi bounds ─────────────────────────────────────────────────────────

  bool _isInKarachi(LatLng latlng) {
    return Geolocator.distanceBetween(
          latlng.latitude,
          latlng.longitude,
          _kKarachiCenter.latitude,
          _kKarachiCenter.longitude,
        ) <=
        _kKarachiRadiusM;
  }

  // ── GPS ────────────────────────────────────────────────────────────────────

  Future<void> _goToCurrentLocation() async {
    setState(() => _gpsLoading = true);
    try {
      final result = await resolveCurrentLocation();
      if (!result.isAvailable) {
        if (mounted) {
          showLocationRecoverySnack(
            context,
            result.status,
            onRetry: _goToCurrentLocation,
          );
        }
        return;
      }
      final pos = result.position!;
      final latlng = LatLng(pos.latitude, pos.longitude);
      _moveMap(latlng);
      await _resolveAndSet(latlng);
    } finally {
      if (mounted) setState(() => _gpsLoading = false);
    }
  }

  // ── Google Geocoding API (reverse) ─────────────────────────────────────────

  Future<String?> _reverseGeocode(LatLng latlng) async {
    try {
      final res = await _geoDio.get(
        'https://maps.googleapis.com/maps/api/geocode/json',
        queryParameters: {
          'latlng': '${latlng.latitude},${latlng.longitude}',
          'key': _kMapsApiKey,
          'language': 'en',
        },
      );
      final results = res.data['results'] as List?;
      if (results != null && results.isNotEmpty) {
        final address = results.first['formatted_address'] as String?;
        if (address != null && address.trim().isNotEmpty) return address;
      }
    } catch (_) {}
    return GeocodingService.addressFromCoordinates(
      latlng.latitude,
      latlng.longitude,
    );
  }

  Future<void> _resolveAndSet(LatLng latlng) async {
    if (!mounted) return;
    final myGeneration = ++_geocodeGeneration;
    setState(() {
      _picked = latlng;
      _cameraCenter = latlng;
      _reverseGeocoding = true;
      _addressLabel = '';
    });
    final address = await _reverseGeocode(latlng);
    if (!mounted) return;
    // A newer request has since started (user moved the map again before
    // this one returned) — drop this stale result instead of overwriting a
    // fresher selection with an out-of-order response.
    if (myGeneration != _geocodeGeneration) return;
    setState(() {
      _addressLabel = address ?? '';
      _reverseGeocoding = false;
    });
    if (address == null || address.trim().isEmpty) {
      _showSnack(context.l10n.locationResolveFailed);
    }
  }

  void _moveMap(LatLng latlng) {
    _skipNextIdle = true;
    _mapCtrl?.animateCamera(
      CameraUpdate.newCameraPosition(CameraPosition(target: latlng, zoom: 16)),
    );
  }

  // ── Camera events ──────────────────────────────────────────────────────────

  void _onCameraMove(CameraPosition pos) {
    _cameraCenter = pos.target;
    if (!_isDragging) setState(() => _isDragging = true);
    // A new gesture is in progress — drop any pending debounced geocode from
    // a previous idle so it can never fire against a now-stale position.
    _geocodeDebounce?.cancel();
  }

  void _onCameraIdle() {
    if (mounted) setState(() => _isDragging = false);
    if (_skipNextIdle) {
      _skipNextIdle = false;
      return;
    }
    final center = _cameraCenter;
    if (center == null) return;

    // Debounce ~600ms so a quick series of small drag-stops only spends one
    // reverse-geocode call, on the position the map actually settles at.
    _geocodeDebounce?.cancel();
    _geocodeDebounce = Timer(const Duration(milliseconds: 600), () {
      if (mounted) _resolveAndSet(center);
    });
  }

  // ── Places Autocomplete ────────────────────────────────────────────────────

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    final generation = ++_autocompleteGeneration;
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _predictions = [];
        _searching = false;
        _lastCompletedQuery = null;
        _searchFailed = false;
      });
      return;
    }
    setState(() {
      _lastCompletedQuery = null;
      _searchFailed = false;
    });
    if (trimmed.length < 3) return;
    _debounce = Timer(
      const Duration(milliseconds: 500),
      () => _runAutocomplete(trimmed, generation),
    );
  }

  Future<void> _runAutocomplete(
    String query, [
    int? requestedGeneration,
  ]) async {
    if (!mounted) return;
    final generation = requestedGeneration ?? ++_autocompleteGeneration;
    final biasCenter = _cameraCenter ?? _picked ?? _kKarachiCenter;
    setState(() {
      _searching = true;
      _searchFailed = false;
    });
    try {
      final res = await _geoDio.get(
        'https://maps.googleapis.com/maps/api/place/autocomplete/json',
        queryParameters: {
          'input': query,
          'key': _kMapsApiKey,
          'components': 'country:pk',
          // A smaller local bias lets named places/landmarks rank alongside
          // street addresses. Follow the map's current center when available,
          // with central Karachi as the initial fallback.
          'location': '${biasCenter.latitude},${biasCenter.longitude}',
          'origin': '${biasCenter.latitude},${biasCenter.longitude}',
          'radius': '25000',
          'region': 'pk',
          'language': 'en',
          'sessiontoken': _placesSessionToken,
        },
      );
      if (!mounted || generation != _autocompleteGeneration) return;
      final status = res.data['status'] as String?;
      if (status != 'OK' && status != 'ZERO_RESULTS') {
        setState(() {
          _predictions = [];
          _lastCompletedQuery = query;
          _searchFailed = true;
        });
        return;
      }
      final raw = (res.data['predictions'] as List?) ?? [];
      setState(() {
        _predictions = raw
            .whereType<Map>()
            .take(5)
            .map((p) {
              final sf = p['structured_formatting'] as Map?;
              final placeId = p['place_id'] as String?;
              if (placeId == null || placeId.isEmpty) return null;
              return _PlacePrediction(
                placeId: placeId,
                mainText:
                    (sf?['main_text'] as String?) ??
                    (p['description'] as String? ?? ''),
                secondaryText: (sf?['secondary_text'] as String?) ?? '',
              );
            })
            .whereType<_PlacePrediction>()
            .toList();
        _lastCompletedQuery = query;
      });
    } catch (_) {
      if (mounted && generation == _autocompleteGeneration) {
        setState(() {
          _predictions = [];
          _lastCompletedQuery = query;
          _searchFailed = true;
        });
      }
    } finally {
      if (mounted && generation == _autocompleteGeneration) {
        setState(() => _searching = false);
      }
    }
  }

  // ── Place Details (on prediction tap) ─────────────────────────────────────

  Future<void> _selectPrediction(_PlacePrediction prediction) async {
    _autocompleteGeneration++;
    _searchCtrl.clear();
    FocusScope.of(context).unfocus();
    setState(() {
      _predictions = [];
      _searching = true;
    });
    try {
      final res = await _geoDio.get(
        'https://maps.googleapis.com/maps/api/place/details/json',
        queryParameters: {
          'place_id': prediction.placeId,
          'key': _kMapsApiKey,
          'fields': 'geometry,formatted_address',
          'language': 'en',
          'sessiontoken': _placesSessionToken,
        },
      );
      final result = res.data['result'] as Map?;
      if (result == null) {
        if (mounted) _showSnack(context.l10n.locationResolveFailed);
        return;
      }
      final loc = result['geometry']['location'] as Map;
      final latlng = LatLng(
        (loc['lat'] as num).toDouble(),
        (loc['lng'] as num).toDouble(),
      );
      final address =
          (result['formatted_address'] as String?) ??
          '${prediction.mainText}, ${prediction.secondaryText}';

      if (!_isInKarachi(latlng)) {
        if (mounted) _showSnack(context.l10n.locationOutsideKarachi);
        return;
      }

      if (!mounted) return;
      // Invalidate any in-flight/pending drag-based geocode so it can never
      // overwrite this prediction-selected address if it resolves later.
      _geocodeDebounce?.cancel();
      _geocodeGeneration++;
      setState(() {
        _picked = latlng;
        _cameraCenter = latlng;
        _addressLabel = address;
        _reverseGeocoding = false;
      });
      _moveMap(latlng);
      _placesSessionToken = _newPlacesSessionToken();
    } catch (_) {
      if (mounted) _showSnack(context.l10n.locationResolveFailed);
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  // ── Map tap (moves center pin) ─────────────────────────────────────────────

  void _onMapTap(LatLng latlng) {
    _moveMap(latlng);
    _resolveAndSet(latlng);
  }

  // ── Confirm ────────────────────────────────────────────────────────────────

  void _confirm() {
    if (_picked == null) return;
    Navigator.of(context).pop(
      PickedLocation(
        latitude: _picked!.latitude,
        longitude: _picked!.longitude,
        address: _addressLabel,
      ),
    );
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.of(context).size.height;
    final topPad = MediaQuery.of(context).padding.top;

    return SizedBox(
      height: screenH - topPad - 24,
      child: Column(
        children: [
          _buildHandle(),
          _buildSearchBar(),
          if (_predictions.isNotEmpty) _buildPredictionList(),
          if (_predictions.isEmpty &&
              !_searching &&
              _lastCompletedQuery == _searchCtrl.text.trim())
            _buildSearchMessage(),
          Expanded(child: _buildMap()),
          _buildBottomPanel(),
        ],
      ),
    );
  }

  Widget _buildHandle() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: _colors.border,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              onChanged: _onSearchChanged,
              textInputAction: TextInputAction.search,
              onSubmitted: (v) {
                final query = v.trim();
                if (query.length >= 3) _runAutocomplete(query);
              },
              style: TextStyle(fontSize: 14, color: _colors.textPrimary),
              decoration: InputDecoration(
                hintText: context.l10n.locationSearchHint,
                hintStyle: TextStyle(
                  color: _colors.textSecondary,
                  fontSize: 14,
                ),
                prefixIcon: _searching
                    ? Padding(
                        padding: const EdgeInsets.all(12),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: _colors.primary,
                          ),
                        ),
                      )
                    : Icon(
                        Icons.search_rounded,
                        size: 20,
                        color: _colors.textSecondary,
                      ),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(
                          Icons.clear,
                          size: 18,
                          color: _colors.textSecondary,
                        ),
                        onPressed: () {
                          _autocompleteGeneration++;
                          _searchCtrl.clear();
                          setState(() {
                            _predictions = [];
                            _lastCompletedQuery = null;
                            _searchFailed = false;
                          });
                        },
                      )
                    : null,
                filled: true,
                fillColor: _colors.surfaceSubtle,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(_rButton),
                  borderSide: BorderSide(color: _colors.controlBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(_rButton),
                  borderSide: BorderSide(color: _colors.controlBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(_rButton),
                  borderSide: BorderSide(color: _colors.primary, width: 1.4),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _gpsLoading ? null : _goToCurrentLocation,
            child: Container(
              width: _hRow,
              height: _hRow,
              decoration: BoxDecoration(
                color: _colors.softTeal,
                borderRadius: BorderRadius.circular(_rButton),
                border: Border.all(color: _colors.primary),
              ),
              child: _gpsLoading
                  ? Padding(
                      padding: const EdgeInsets.all(12),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _colors.primary,
                      ),
                    )
                  : Icon(
                      Icons.my_location_rounded,
                      size: 20,
                      color: _colors.primary,
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchMessage() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: _colors.surface,
          borderRadius: BorderRadius.circular(_rCard),
          border: Border.all(color: _colors.border),
        ),
        child: Text(
          _searchFailed
              ? context.l10n.locationSearchFailed
              : context.l10n.locationNoSuggestions,
          style: TextStyle(fontSize: 13, color: _colors.textSecondary),
        ),
      ),
    );
  }

  Widget _buildPredictionList() {
    return Container(
      constraints: const BoxConstraints(maxHeight: 220),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      // A card here is `surface` + radius 16 + a 1px hairline. The BoxShadow
      // that used to lift this list — and the derived `textPrimary` alpha it
      // was drawn in — are gone; nothing inside a HandyGo screen casts one.
      decoration: BoxDecoration(
        color: _colors.surface,
        borderRadius: BorderRadius.circular(_rCard),
        border: Border.all(color: _colors.border),
      ),
      child: ListView.builder(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        itemCount: _predictions.length,
        itemBuilder: (_, i) {
          final p = _predictions[i];
          return InkWell(
            borderRadius: BorderRadius.circular(_rCard),
            onTap: () => _selectPrediction(p),
            child: Container(
              // A result line is a tappable row — never below the prototype's
              // 44 minimum, however short the place name is.
              constraints: const BoxConstraints(minHeight: _hRow),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Icon(
                      Icons.location_on_outlined,
                      size: 18,
                      color: _colors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.mainText,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: _colors.textPrimary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (p.secondaryText.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            p.secondaryText,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: _colors.textSecondary,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMap() {
    final initial = _picked ?? _kKarachiCenter;

    return Stack(
      children: [
        // ── Map ─────────────────────────────────────────────────────────────
        Positioned.fill(
          child: GoogleMap(
            initialCameraPosition: CameraPosition(target: initial, zoom: 14),
            onMapCreated: (ctrl) => _mapCtrl = ctrl,
            onTap: _onMapTap,
            onCameraMove: _onCameraMove,
            onCameraIdle: _onCameraIdle,
            // Claim pan/drag gestures immediately so they can't be won by the
            // enclosing modal bottom sheet's drag-to-dismiss detector — without
            // this, dragging the map was being interpreted as a swipe to close
            // the sheet instead of panning the camera.
            gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
              Factory<OneSequenceGestureRecognizer>(
                () => EagerGestureRecognizer(),
              ),
            },
            markers: const {},
            mapType: MapType.normal,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            buildingsEnabled: true,
            tiltGesturesEnabled: false,
            rotateGesturesEnabled: false,
            compassEnabled: false,
          ),
        ),

        // ── Center-pin overlay ───────────────────────────────────────────────
        // IgnorePointer so touch events pass through to the map.
        IgnorePointer(
          child: Center(
            child: Transform.translate(
              // Shift pin up so its tip sits exactly at the map centre.
              offset: const Offset(0, -28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Pin head — scales up slightly while dragging.
                  //
                  // The teal glow this used to cast was a `primary` derived
                  // with `withValues(alpha:)`, which the palette does not
                  // allow. The lift now reads as a solid `onPrimary` ring
                  // that thickens on drag — same "picked up" cue, drawn
                  // entirely in named tokens, and more legible over dark
                  // satellite tiles than a soft shadow ever was.
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    curve: Curves.easeOut,
                    width: _isDragging ? 46 : 40,
                    height: _isDragging ? 46 : 40,
                    decoration: BoxDecoration(
                      color: _colors.primary,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _colors.onPrimary,
                        width: _isDragging ? 3.5 : 2.5,
                      ),
                    ),
                    child: Icon(
                      Icons.location_on_rounded,
                      color: _colors.onPrimary,
                      size: 22,
                    ),
                  ),
                  // Pin stem
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 3,
                    height: _isDragging ? 20 : 16,
                    decoration: BoxDecoration(
                      color: _colors.primary,
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(2),
                        bottomRight: Radius.circular(2),
                      ),
                    ),
                  ),
                  // Ground dot — fades when the pin is lifted. Drawn in
                  // `controlBorder`, the palette's own mid tone, instead of a
                  // `textPrimary` alpha derivation.
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 150),
                    opacity: _isDragging ? 0.3 : 1.0,
                    child: Container(
                      width: 10,
                      height: 5,
                      decoration: BoxDecoration(
                        color: _colors.controlBorder,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomPanel() {
    final canConfirm =
        _picked != null &&
        !_reverseGeocoding &&
        _addressLabel.trim().isNotEmpty;
    final resolveFailed =
        _picked != null && !_reverseGeocoding && _addressLabel.trim().isEmpty;

    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        14,
        16,
        MediaQuery.of(context).padding.bottom + 16,
      ),
      decoration: BoxDecoration(
        color: _colors.surface,
        border: Border(top: BorderSide(color: _colors.border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildAddressReadout(resolveFailed: resolveFailed),
          const SizedBox(height: 12),

          // ── Confirm ────────────────────────────────────────────────────────
          ElevatedButton(
            onPressed: canConfirm ? _confirm : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: _colors.primary,
              foregroundColor: _colors.onPrimary,
              disabledBackgroundColor: _colors.surfaceSubtle,
              disabledForegroundColor: _colors.textSecondary,
              // 52 — the prototype's primary-button height. `minimumSize`
              // rather than fixed padding so a 2.0 text scale grows the
              // button instead of clipping its label.
              minimumSize: const Size.fromHeight(_hAction),
              // Standard density pinned: the platform-adaptive default shaves
              // 4px off on desktop-class devices, which would put this control
              // under the prototype's 52 floor.
              visualDensity: VisualDensity.standard,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(_rButton),
              ),
              elevation: 0,
            ),
            child: Text(
              context.l10n.locationUseThis,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }

  /// The address the pin currently resolves to — a card, not a bare line, so
  /// the one piece of information the confirm button acts on reads as the
  /// panel's subject.
  ///
  /// Three states, each with its own token pairing and no derived colours:
  /// resolving (`surfaceSubtle`), resolved (`softTeal` + `primary` hairline),
  /// and failed-to-resolve (`errorSoft` + `error` hairline) — the last one is
  /// why the button below stays disabled, so it says so instead of leaving a
  /// dead CTA unexplained.
  Widget _buildAddressReadout({required bool resolveFailed}) {
    final hasPick = _picked != null;

    final Color fill;
    final Color line;
    final Color icon;
    if (resolveFailed) {
      fill = _colors.errorSoft;
      line = _colors.error;
      icon = _colors.error;
    } else if (hasPick && !_reverseGeocoding) {
      fill = _colors.softTeal;
      line = _colors.primary;
      icon = _colors.primary;
    } else {
      fill = _colors.surfaceSubtle;
      line = _colors.border;
      icon = _colors.textSecondary;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(_rCard),
        border: Border.all(color: line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(
              resolveFailed
                  ? Icons.error_outline_rounded
                  : Icons.location_on_rounded,
              size: 18,
              color: icon,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _reverseGeocoding
                ? Row(
                    children: [
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: _colors.primary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          context.l10n.locationGettingAddress,
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.35,
                            color: _colors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  )
                : Text(
                    !hasPick
                        ? context.l10n.locationMoveMapHint
                        : resolveFailed
                        ? context.l10n.locationResolveFailed
                        : _addressLabel,
                    // A Karachi address routinely runs three lines; it wraps
                    // rather than truncating, because this is the text the
                    // client is being asked to confirm.
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.35,
                      color: resolveFailed
                          ? _colors.error
                          : hasPick
                          ? _colors.textPrimary
                          : _colors.textSecondary,
                      fontWeight: hasPick && !resolveFailed
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
