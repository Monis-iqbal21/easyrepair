import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

// ── API key (dart-define) ──────────────────────────────────────────────────────
const _kMapsApiKey = String.fromEnvironment('GOOGLE_MAPS_API_KEY');

// ── Karachi reference ─────────────────────────────────────────────────────────
const _kKarachiCenter = LatLng(24.8607, 67.0011);
const _kKarachiRadiusM = 55000.0; // 55 km

// ── Palette ───────────────────────────────────────────────────────────────────
const _kOrange  = Color(0xFF1D9E75);
const _kDark    = Color(0xFF1A1A1A);
const _kGray    = Color(0xFF6B7280);
const _kBorder  = Color(0xFFE2E8F0);
const _kSurface = Color(0xFFF9FAFB);

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
}) {
  return showModalBottomSheet<PickedLocation>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _LocationPickerSheet(initial: initial),
  );
}

// ── Sheet widget ──────────────────────────────────────────────────────────────

class _LocationPickerSheet extends StatefulWidget {
  final PickedLocation? initial;
  const _LocationPickerSheet({this.initial});

  @override
  State<_LocationPickerSheet> createState() => _LocationPickerSheetState();
}

class _LocationPickerSheetState extends State<_LocationPickerSheet> {
  GoogleMapController? _mapCtrl;

  LatLng? _picked;
  String  _addressLabel = '';
  bool    _reverseGeocoding = false;
  LatLng? _cameraCenter;

  /// Prevents [_onCameraIdle] from re-geocoding after a programmatic move.
  bool _skipNextIdle = false;

  /// True while the user is actively dragging the map.
  bool _isDragging = false;

  // ── Search ─────────────────────────────────────────────────────────────────
  final _searchCtrl  = TextEditingController();
  bool _searching    = false;
  List<_PlacePrediction> _predictions = [];
  Timer? _debounce;

  // ── GPS ────────────────────────────────────────────────────────────────────
  bool _gpsLoading = false;

  // ── Bare Dio for Google APIs (no auth interceptors) ────────────────────────
  late final Dio _geoDio;

  // ── Init / dispose ─────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _geoDio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 8),
      ),
    );
    if (widget.initial != null) {
      _picked       = LatLng(widget.initial!.latitude, widget.initial!.longitude);
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
    _mapCtrl?.dispose();
    _geoDio.close(force: true);
    super.dispose();
  }

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
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        if (mounted) _showSnack('Location permission denied.');
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
      final latlng = LatLng(pos.latitude, pos.longitude);
      _moveMap(latlng);
      await _resolveAndSet(latlng);
    } catch (_) {
      if (mounted) _showSnack('Could not get current location.');
    } finally {
      if (mounted) setState(() => _gpsLoading = false);
    }
  }

  // ── Google Geocoding API (reverse) ─────────────────────────────────────────

  Future<String> _reverseGeocode(LatLng latlng) async {
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
        return (results.first['formatted_address'] as String?) ??
            'Selected location';
      }
    } catch (_) {}
    return 'Selected location';
  }

  Future<void> _resolveAndSet(LatLng latlng) async {
    if (!mounted) return;
    setState(() {
      _picked           = latlng;
      _cameraCenter     = latlng;
      _reverseGeocoding = true;
      _addressLabel     = '';
    });
    final address = await _reverseGeocode(latlng);
    if (!mounted) return;
    setState(() {
      _addressLabel     = address;
      _reverseGeocoding = false;
    });
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
  }

  Future<void> _onCameraIdle() async {
    if (mounted) setState(() => _isDragging = false);
    if (_skipNextIdle) {
      _skipNextIdle = false;
      return;
    }
    final center = _cameraCenter;
    if (center == null) return;
    await _resolveAndSet(center);
  }

  // ── Places Autocomplete ────────────────────────────────────────────────────

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      setState(() {
        _predictions = [];
        _searching   = false;
      });
      return;
    }
    _debounce = Timer(
      const Duration(milliseconds: 500),
      () => _runAutocomplete(query.trim()),
    );
  }

  Future<void> _runAutocomplete(String query) async {
    if (!mounted) return;
    setState(() => _searching = true);
    try {
      final res = await _geoDio.get(
        'https://maps.googleapis.com/maps/api/place/autocomplete/json',
        queryParameters: {
          'input'     : query,
          'key'       : _kMapsApiKey,
          'components': 'country:pk',
          'location'  : '${_kKarachiCenter.latitude},${_kKarachiCenter.longitude}',
          'radius'    : '50000',
          'language'  : 'en',
        },
      );
      final raw = (res.data['predictions'] as List?) ?? [];
      if (mounted) {
        setState(() {
          _predictions = raw.take(5).map((p) {
            final sf = p['structured_formatting'] as Map?;
            return _PlacePrediction(
              placeId      : p['place_id'] as String,
              mainText     : (sf?['main_text']      as String?) ?? (p['description'] as String? ?? ''),
              secondaryText: (sf?['secondary_text'] as String?) ?? '',
            );
          }).toList();
        });
      }
    } catch (_) {
      if (mounted) setState(() => _predictions = []);
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  // ── Place Details (on prediction tap) ─────────────────────────────────────

  Future<void> _selectPrediction(_PlacePrediction prediction) async {
    _searchCtrl.clear();
    FocusScope.of(context).unfocus();
    setState(() {
      _predictions = [];
      _searching   = true;
    });
    try {
      final res = await _geoDio.get(
        'https://maps.googleapis.com/maps/api/place/details/json',
        queryParameters: {
          'place_id': prediction.placeId,
          'key'     : _kMapsApiKey,
          'fields'  : 'geometry,formatted_address',
          'language': 'en',
        },
      );
      final result = res.data['result'] as Map?;
      if (result == null) {
        if (mounted) _showSnack('Could not resolve selected location.');
        return;
      }
      final loc    = result['geometry']['location'] as Map;
      final latlng = LatLng(
        (loc['lat'] as num).toDouble(),
        (loc['lng'] as num).toDouble(),
      );
      final address = (result['formatted_address'] as String?) ??
          '${prediction.mainText}, ${prediction.secondaryText}';

      if (!_isInKarachi(latlng)) {
        if (mounted) _showSnack('Location is outside the Karachi service area.');
        return;
      }

      if (!mounted) return;
      setState(() {
        _picked           = latlng;
        _cameraCenter     = latlng;
        _addressLabel     = address;
        _reverseGeocoding = false;
      });
      _moveMap(latlng);
    } catch (_) {
      if (mounted) _showSnack('Could not resolve selected location.');
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
        latitude : _picked!.latitude,
        longitude: _picked!.longitude,
        address  : _addressLabel,
      ),
    );
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content  : Text(msg),
        behavior : SnackBarBehavior.floating,
        shape    : RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.of(context).size.height;
    final topPad  = MediaQuery.of(context).padding.top;

    return Container(
      height    : screenH - topPad - 24,
      decoration: const BoxDecoration(
        color        : Colors.white,
        borderRadius : BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          _buildHandle(),
          _buildSearchBar(),
          if (_predictions.isNotEmpty) _buildPredictionList(),
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
        width : 40,
        height: 4,
        decoration: BoxDecoration(
          color        : const Color(0xFFCBD5E1),
          borderRadius : BorderRadius.circular(2),
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
              controller     : _searchCtrl,
              onChanged      : _onSearchChanged,
              textInputAction: TextInputAction.search,
              onSubmitted    : (v) {
                if (v.trim().isNotEmpty) _runAutocomplete(v.trim());
              },
              decoration: InputDecoration(
                hintText: 'Search for an area or landmark…',
                hintStyle: const TextStyle(color: _kGray, fontSize: 13.5),
                prefixIcon: _searching
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width : 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color      : _kOrange,
                          ),
                        ),
                      )
                    : const Icon(Icons.search_rounded, size: 20, color: _kGray),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon    : const Icon(Icons.clear, size: 18, color: _kGray),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _predictions = []);
                        },
                      )
                    : null,
                filled      : true,
                fillColor   : _kSurface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide  : const BorderSide(color: _kBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide  : const BorderSide(color: _kBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide  : const BorderSide(color: _kOrange, width: 1.4),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _gpsLoading ? null : _goToCurrentLocation,
            child: Container(
              width : 44,
              height: 44,
              decoration: BoxDecoration(
                color        : _kOrange.withValues(alpha: 0.08),
                borderRadius : BorderRadius.circular(12),
                border       : Border.all(color: _kOrange.withValues(alpha: 0.3)),
              ),
              child: _gpsLoading
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: _kOrange),
                    )
                  : const Icon(Icons.my_location_rounded,
                      size: 20, color: _kOrange),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPredictionList() {
    return Container(
      constraints: const BoxConstraints(maxHeight: 220),
      margin     : const EdgeInsets.fromLTRB(16, 0, 16, 8),
      decoration : BoxDecoration(
        color       : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border      : Border.all(color: _kBorder),
        boxShadow   : [
          BoxShadow(
            color     : Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset    : const Offset(0, 2),
          ),
        ],
      ),
      child: ListView.builder(
        shrinkWrap: true,
        padding   : EdgeInsets.zero,
        itemCount : _predictions.length,
        itemBuilder: (_, i) {
          final p = _predictions[i];
          return InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap       : () => _selectPrediction(p),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child  : Icon(Icons.location_on_outlined,
                        size: 18, color: _kGray),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.mainText,
                          style    : const TextStyle(
                            fontSize  : 13.5,
                            fontWeight: FontWeight.w600,
                            color     : _kDark,
                          ),
                          maxLines : 1,
                          overflow : TextOverflow.ellipsis,
                        ),
                        if (p.secondaryText.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            p.secondaryText,
                            style  : const TextStyle(
                              fontSize: 12,
                              color   : _kGray,
                            ),
                            maxLines: 1,
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
        GoogleMap(
          initialCameraPosition: CameraPosition(target: initial, zoom: 14),
          onMapCreated          : (ctrl) => _mapCtrl = ctrl,
          onTap                 : _onMapTap,
          onCameraMove          : _onCameraMove,
          onCameraIdle          : _onCameraIdle,
          markers               : const {},
          mapType               : MapType.normal,
          myLocationEnabled     : true,
          myLocationButtonEnabled: false,
          zoomControlsEnabled   : false,
          mapToolbarEnabled     : false,
          buildingsEnabled      : true,
          tiltGesturesEnabled   : false,
          rotateGesturesEnabled : false,
          compassEnabled        : false,
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
                  // Pin head — scales up slightly while dragging
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    curve   : Curves.easeOut,
                    width   : _isDragging ? 46 : 40,
                    height  : _isDragging ? 46 : 40,
                    decoration: BoxDecoration(
                      color    : _kOrange,
                      shape    : BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color     : _kOrange.withValues(
                              alpha: _isDragging ? 0.45 : 0.3),
                          blurRadius: _isDragging ? 18 : 12,
                          offset    : const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.location_on_rounded,
                      color: Colors.white,
                      size : 22,
                    ),
                  ),
                  // Pin stem
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width   : 3,
                    height  : _isDragging ? 20 : 16,
                    decoration: BoxDecoration(
                      color       : _kOrange,
                      borderRadius: const BorderRadius.only(
                        bottomLeft : Radius.circular(2),
                        bottomRight: Radius.circular(2),
                      ),
                    ),
                  ),
                  // Ground shadow dot — fades when lifted
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 150),
                    opacity : _isDragging ? 0.3 : 1.0,
                    child: Container(
                      width : 10,
                      height: 5,
                      decoration: BoxDecoration(
                        color       : Colors.black.withValues(alpha: 0.18),
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
    final canConfirm = _picked != null && !_reverseGeocoding;

    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        14,
        16,
        MediaQuery.of(context).padding.bottom + 16,
      ),
      decoration: const BoxDecoration(
        color : Colors.white,
        border: Border(top: BorderSide(color: _kBorder)),
      ),
      child: Column(
        mainAxisSize      : MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Selected address ───────────────────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.location_on_rounded,
                size : 18,
                color: _picked != null ? _kOrange : _kGray,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _reverseGeocoding
                    ? const Row(
                        children: [
                          SizedBox(
                            width : 14,
                            height: 14,
                            child : CircularProgressIndicator(
                                strokeWidth: 2, color: _kOrange),
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Getting address…',
                            style: TextStyle(fontSize: 13, color: _kGray),
                          ),
                        ],
                      )
                    : Text(
                        _picked == null
                            ? 'Move the map or tap to pick a location'
                            : _addressLabel.isNotEmpty
                                ? _addressLabel
                                : 'Selected location',
                        style: TextStyle(
                          fontSize  : 13,
                          color     : _picked == null ? _kGray : _kDark,
                          fontWeight: _picked != null
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // ── Confirm button ─────────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: canConfirm ? _confirm : null,
              style: ElevatedButton.styleFrom(
                backgroundColor       : _kOrange,
                foregroundColor       : Colors.white,
                disabledBackgroundColor: _kOrange.withValues(alpha: 0.4),
                disabledForegroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape  : RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: const Text(
                'Use This Location',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
