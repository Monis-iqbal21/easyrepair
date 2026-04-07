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
}
