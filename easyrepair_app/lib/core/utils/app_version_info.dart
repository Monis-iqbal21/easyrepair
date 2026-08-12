import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Runtime app version/build — single source of truth for every "App
/// Version"/About-page display. Never hardcode a version string; always
/// read it from the platform package metadata (pubspec.yaml's `version:`
/// at build time), so this can never drift from what actually shipped.
final appVersionInfoProvider = FutureProvider<PackageInfo>((ref) {
  return PackageInfo.fromPlatform();
});
