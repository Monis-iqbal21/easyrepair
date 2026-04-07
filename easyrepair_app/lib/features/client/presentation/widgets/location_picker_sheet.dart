import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

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

// ── Sheet ─────────────────────────────────────────────────────────────────────

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

// ── Palette (mirrors post_job_page palette) ──────────────────────────────────
const _kGreen  = Color(0xFFFF5F15);
const _kDark   = Color(0xFF1A1A1A);
const _kGray   = Color(0xFF6B7280);
const _kBorder = Color(0xFFE2E8F0);
const _kSurface = Color(0xFFF9FAFB);

class _LocationPickerSheet extends StatefulWidget {
  final PickedLocation? initial;
  const _LocationPickerSheet({this.initial});

  @override
  State<_LocationPickerSheet> createState() => _LocationPickerSheetState();
}

class _LocationPickerSheetState extends State<_LocationPickerSheet> {
  GoogleMapController? _mapCtrl;
  LatLng? _picked;
  String _addressLabel = '';
  bool _reverseGeocoding = false;

  // Search
  final _searchCtrl = TextEditingController();
  bool _searching = false;
  List<Location> _searchResults = [];
  Timer? _debounce;

  // Current-location loading
  bool _gpsLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.initial != null) {
      _picked = LatLng(widget.initial!.latitude, widget.initial!.longitude);
      _addressLabel = widget.initial!.address;
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _debounce?.cancel();
    _mapCtrl?.dispose();
    super.dispose();
  }

  // ── GPS ───────────────────────────────────────────────────────────────────

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
      await _pickLatLng(latlng);
    } catch (_) {
      if (mounted) _showSnack('Could not get current location.');
    } finally {
      if (mounted) setState(() => _gpsLoading = false);
    }
  }

  // ── Map tap / drag ────────────────────────────────────────────────────────

  Future<void> _pickLatLng(LatLng latlng) async {
    setState(() {
      _picked = latlng;
      _reverseGeocoding = true;
      _addressLabel = '';
    });
    try {
      final placemarks = await placemarkFromCoordinates(
        latlng.latitude,
        latlng.longitude,
      );
      if (placemarks.isNotEmpty && mounted) {
        final p = placemarks.first;
        final parts = <String>[
          if (p.street?.isNotEmpty == true) p.street!,
          if (p.subLocality?.isNotEmpty == true) p.subLocality!,
          if (p.locality?.isNotEmpty == true) p.locality!,
        ];
        setState(() => _addressLabel = parts.join(', '));
      }
    } catch (_) {
      if (mounted) {
        setState(() => _addressLabel =
            '${latlng.latitude.toStringAsFixed(5)}, '
            '${latlng.longitude.toStringAsFixed(5)}');
      }
    } finally {
      if (mounted) setState(() => _reverseGeocoding = false);
    }
  }

  void _moveMap(LatLng latlng) {
    _mapCtrl?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: latlng, zoom: 16),
      ),
    );
  }

  // ── Search ────────────────────────────────────────────────────────────────

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      setState(() { _searchResults = []; _searching = false; });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 600), () => _runSearch(query.trim()));
  }

  Future<void> _runSearch(String query) async {
    setState(() => _searching = true);
    try {
      final results = await locationFromAddress(query);
      if (mounted) setState(() => _searchResults = results);
    } catch (_) {
      if (mounted) setState(() => _searchResults = []);
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _selectSearchResult(Location loc) async {
    final latlng = LatLng(loc.latitude, loc.longitude);
    _searchCtrl.clear();
    setState(() => _searchResults = []);
    FocusScope.of(context).unfocus();
    _moveMap(latlng);
    await _pickLatLng(latlng);
  }

  // ── Confirm ───────────────────────────────────────────────────────────────

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

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.of(context).size.height;
    final topPad = MediaQuery.of(context).padding.top;

    return Container(
      height: screenH - topPad - 24,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          _buildHandle(),
          _buildSearchBar(),
          if (_searchResults.isNotEmpty) _buildSearchResults(),
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
          color: const Color(0xFFCBD5E1),
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
                if (v.trim().isNotEmpty) _runSearch(v.trim());
              },
              decoration: InputDecoration(
                hintText: 'Search for an area or landmark…',
                hintStyle: const TextStyle(color: _kGray, fontSize: 13.5),
                prefixIcon: _searching
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: _kGreen,
                          ),
                        ),
                      )
                    : const Icon(Icons.search_rounded, size: 20, color: _kGray),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18, color: _kGray),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _searchResults = []);
                        },
                      )
                    : null,
                filled: true,
                fillColor: _kSurface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: _kBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: _kBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: _kGreen, width: 1.4),
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
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _kGreen.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _kGreen.withValues(alpha: 0.3)),
              ),
              child: _gpsLoading
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: _kGreen),
                    )
                  : const Icon(Icons.my_location_rounded,
                      size: 20, color: _kGreen),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    return Container(
      constraints: const BoxConstraints(maxHeight: 200),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListView.builder(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        itemCount: _searchResults.length,
        itemBuilder: (_, i) {
          final loc = _searchResults[i];
          return ListTile(
            dense: true,
            leading: const Icon(Icons.location_on_outlined,
                size: 18, color: _kGray),
            title: Text(
              '${loc.latitude.toStringAsFixed(4)}, '
              '${loc.longitude.toStringAsFixed(4)}',
              style: const TextStyle(fontSize: 13, color: _kDark),
            ),
            onTap: () => _selectSearchResult(loc),
          );
        },
      ),
    );
  }

  Widget _buildMap() {
    final initial = widget.initial != null
        ? LatLng(widget.initial!.latitude, widget.initial!.longitude)
        : const LatLng(24.8607, 67.0011); // Default: Karachi

    return GoogleMap(
      initialCameraPosition: CameraPosition(target: initial, zoom: 14),
      onMapCreated: (ctrl) => _mapCtrl = ctrl,
      onTap: _pickLatLng,
      markers: _picked != null
          ? {
              Marker(
                markerId: const MarkerId('picked'),
                position: _picked!,
                icon: BitmapDescriptor.defaultMarkerWithHue(
                    BitmapDescriptor.hueGreen),
              ),
            }
          : {},
      myLocationEnabled: true,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
    );
  }

  Widget _buildBottomPanel() {
    final canConfirm = _picked != null && !_reverseGeocoding;

    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        MediaQuery.of(context).padding.bottom + 16,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: _kBorder)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_picked == null)
            const Text(
              'Tap on the map to pick a location',
              style: TextStyle(fontSize: 13, color: _kGray),
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.location_on_rounded,
                    size: 16, color: _kGreen),
                const SizedBox(width: 6),
                Expanded(
                  child: _reverseGeocoding
                      ? Row(children: const [
                          SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: _kGreen),
                          ),
                          SizedBox(width: 8),
                          Text('Getting address…',
                              style: TextStyle(fontSize: 13, color: _kGray)),
                        ])
                      : Text(
                          _addressLabel.isNotEmpty
                              ? _addressLabel
                              : '${_picked!.latitude.toStringAsFixed(5)}, '
                                  '${_picked!.longitude.toStringAsFixed(5)}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: _kDark,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                ),
              ],
            ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: canConfirm ? _confirm : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: _kGreen,
                foregroundColor: Colors.white,
                disabledBackgroundColor: _kGreen.withValues(alpha: 0.4),
                disabledForegroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: const Text(
                'Confirm Location',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
