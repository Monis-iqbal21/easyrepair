import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';

/// Thin wrapper around the [geocoding] package.
/// Resolves a human-readable address string into geographic coordinates.
class GeocodingService {
  const GeocodingService._();

  /// Returns the first [Location] that matches [address], or `null` when no
  /// result is found.
  ///
  /// Throws a [PlatformException] / [NoResultFoundException] on hard errors
  /// (no network, geocoder unavailable, etc.) so callers can distinguish
  /// "empty result" from "platform failure".
  static Future<Location?> coordinatesFromAddress(String address) async {
    debugPrint('[GeocodingService] Resolving address: "$address"');
    List<Location> results;
    try {
      results = await locationFromAddress(address);
    } catch (e) {
      debugPrint('[GeocodingService] locationFromAddress threw: $e');
      rethrow;
    }

    if (results.isEmpty) {
      debugPrint('[GeocodingService] No geocoding results for: "$address"');
      return null;
    }

    final loc = results.first;
    debugPrint(
      '[GeocodingService] Resolved "${address}" → '
      'lat=${loc.latitude.toStringAsFixed(6)}, '
      'lng=${loc.longitude.toStringAsFixed(6)}',
    );
    return loc;
  }

  /// Resolves geographic coordinates into a human-readable address using the
  /// device's native geocoder (no HTTP API key required). Used as a fallback
  /// when the Google Geocoding HTTP API is unavailable or returns no result.
  /// Returns `null` on any failure or empty result.
  static Future<String?> addressFromCoordinates(double lat, double lng) async {
    debugPrint('[GeocodingService] Reverse resolving: lat=$lat, lng=$lng');
    try {
      final placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isEmpty) {
        debugPrint('[GeocodingService] No placemarks for lat=$lat, lng=$lng');
        return null;
      }
      final p = placemarks.first;
      final parts = <String>{
        if (p.street != null && p.street!.trim().isNotEmpty) p.street!.trim(),
        if (p.subLocality != null && p.subLocality!.trim().isNotEmpty)
          p.subLocality!.trim(),
        if (p.locality != null && p.locality!.trim().isNotEmpty)
          p.locality!.trim(),
        if (p.administrativeArea != null &&
            p.administrativeArea!.trim().isNotEmpty)
          p.administrativeArea!.trim(),
        if (p.country != null && p.country!.trim().isNotEmpty)
          p.country!.trim(),
      };
      if (parts.isEmpty) return null;
      final address = parts.join(', ');
      debugPrint('[GeocodingService] Reverse resolved → $address');
      return address;
    } catch (e) {
      debugPrint('[GeocodingService] placemarkFromCoordinates threw: $e');
      return null;
    }
  }
}
