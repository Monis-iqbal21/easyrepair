import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

/// HandyGo Support's phone number — the single source of truth for every
/// "Contact Support" affordance that needs to actually dial it (e.g. the
/// Worker-suspended lock screen).
const String kSupportPhoneNumber = '+923320219006';

/// Opens the device's dialer pre-filled with [kSupportPhoneNumber]. Returns
/// whether the dialer was actually launched, so a caller can fall back to
/// showing the number as plain text if the platform refuses (e.g. no
/// telephony capability, as on some tablets/emulators).
Future<bool> launchSupportCall() async {
  final uri = Uri(scheme: 'tel', path: kSupportPhoneNumber);
  try {
    return await launchUrl(uri);
  } catch (e) {
    debugPrint('[SupportContact] failed to launch dialer: $e');
    return false;
  }
}
