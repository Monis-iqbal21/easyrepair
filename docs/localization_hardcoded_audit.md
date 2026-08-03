# Hard-coded visible-string audit

Regenerate with `python tool/audit_report.py` from `easyrepair_app/`.

Every literal that `tool/extract_ui_strings.py` finds in a user-visible position is classified into exactly one category.

| Category | Meaning | Count |
|---|---|---|
| 1 | Dynamic / user / backend content that must remain unchanged | 50 |
| 2 | _Retired_ — bottom-navigation labels are translated now | 0 |
| 3 | Internal technical value, or a fixed name no language changes | 234 |
| 4 | **Missed app-owned visible text that must be localized** | **0** |
| 5 | Approved English-only legal document content awaiting professional translation | 64 |

> Audit passes: no app-owned visible string remains hard-coded.

Category 5 is a product and legal decision, not missed work. The Privacy Policy and Terms bodies stay in their approved English wording until a professionally approved Urdu and Roman Urdu translation exists; the app chrome around them, including the notice that says the document is English only, *is* localized. See `legal_translation_exclusions.md`.

## Category 5 — approved English-only legal content

| File | Strings |
|---|---|
| `lib/core/presentation/pages/privacy_policy_page.dart` | 36 |
| `lib/core/presentation/pages/terms_conditions_page.dart` | 28 |

| File | Line | Literal | Reason |
|---|---|---|---|
| `lib/core/presentation/pages/privacy_policy_page.dart` | 73 | `April 2025` | Approved English-only legal document text - awaiting a professional Urdu / Roman Urdu translation, see docs/legal_translation_exclusions.md |
| `lib/core/presentation/pages/privacy_policy_page.dart` | 75 | `EasyRepair ("we", "our", or "us") is committed to protecting your ` | Approved English-only legal document text - awaiting a professional Urdu / Roman Urdu translation, see docs/legal_translation_exclusions.md |
| `lib/core/presentation/pages/privacy_policy_page.dart` | 83 | `We collect the following types of information to provide and improve our services:` | Approved English-only legal document text - awaiting a professional Urdu / Roman Urdu translation, see docs/legal_translation_exclusions.md |
| `lib/core/presentation/pages/privacy_policy_page.dart` | 88 | `Account Information` | Approved English-only legal document text - awaiting a professional Urdu / Roman Urdu translation, see docs/legal_translation_exclusions.md |
| `lib/core/presentation/pages/privacy_policy_page.dart` | 89 | `When you register, we collect your full name, phone number, and password. Workers may a...` | Approved English-only legal document text - awaiting a professional Urdu / Roman Urdu translation, see docs/legal_translation_exclusions.md |
| `lib/core/presentation/pages/privacy_policy_page.dart` | 93 | `Booking & Job Details` | Approved English-only legal document text - awaiting a professional Urdu / Roman Urdu translation, see docs/legal_translation_exclusions.md |
| `lib/core/presentation/pages/privacy_policy_page.dart` | 94 | `We collect information about the services you request or provide, including job descrip...` | Approved English-only legal document text - awaiting a professional Urdu / Roman Urdu translation, see docs/legal_translation_exclusions.md |
| `lib/core/presentation/pages/privacy_policy_page.dart` | 98 | `Chat & Media` | Approved English-only legal document text - awaiting a professional Urdu / Roman Urdu translation, see docs/legal_translation_exclusions.md |
| `lib/core/presentation/pages/privacy_policy_page.dart` | 99 | `Messages, images, voice notes, and video clips exchanged through our in-app chat are st...` | Approved English-only legal document text - awaiting a professional Urdu / Roman Urdu translation, see docs/legal_translation_exclusions.md |
| `lib/core/presentation/pages/privacy_policy_page.dart` | 103 | `Location Data` | Approved English-only legal document text - awaiting a professional Urdu / Roman Urdu translation, see docs/legal_translation_exclusions.md |
| `lib/core/presentation/pages/privacy_policy_page.dart` | 108 | `Attachments` | Approved English-only legal document text - awaiting a professional Urdu / Roman Urdu translation, see docs/legal_translation_exclusions.md |
| `lib/core/presentation/pages/privacy_policy_page.dart` | 109 | `Files you attach to bookings or chat conversations (photos, videos, documents) are uplo...` | Approved English-only legal document text - awaiting a professional Urdu / Roman Urdu translation, see docs/legal_translation_exclusions.md |
| `lib/core/presentation/pages/privacy_policy_page.dart` | 114 | `We use the information we collect to:` | Approved English-only legal document text - awaiting a professional Urdu / Roman Urdu translation, see docs/legal_translation_exclusions.md |
| `lib/core/presentation/pages/privacy_policy_page.dart` | 119 | `Create and manage your account.` | Approved English-only legal document text - awaiting a professional Urdu / Roman Urdu translation, see docs/legal_translation_exclusions.md |
| `lib/core/presentation/pages/privacy_policy_page.dart` | 122 | `Match clients with suitable workers based on location and service category.` | Approved English-only legal document text - awaiting a professional Urdu / Roman Urdu translation, see docs/legal_translation_exclusions.md |
| `lib/core/presentation/pages/privacy_policy_page.dart` | 126 | `Facilitate bookings, job tracking, and in-app communication.` | Approved English-only legal document text - awaiting a professional Urdu / Roman Urdu translation, see docs/legal_translation_exclusions.md |
| `lib/core/presentation/pages/privacy_policy_page.dart` | 130 | `Send push notifications about job updates and messages.` | Approved English-only legal document text - awaiting a professional Urdu / Roman Urdu translation, see docs/legal_translation_exclusions.md |
| `lib/core/presentation/pages/privacy_policy_page.dart` | 133 | `Improve the reliability and performance of the platform.` | Approved English-only legal document text - awaiting a professional Urdu / Roman Urdu translation, see docs/legal_translation_exclusions.md |
| `lib/core/presentation/pages/privacy_policy_page.dart` | 136 | `Comply with legal obligations and enforce our Terms of Service.` | Approved English-only legal document text - awaiting a professional Urdu / Roman Urdu translation, see docs/legal_translation_exclusions.md |
| `lib/core/presentation/pages/privacy_policy_page.dart` | 145 | `Your data is stored on secure cloud servers. Access tokens are ` | Approved English-only legal document text - awaiting a professional Urdu / Roman Urdu translation, see docs/legal_translation_exclusions.md |
| `lib/core/presentation/pages/privacy_policy_page.dart` | 154 | `We do not sell your personal information to third parties. Your ` | Approved English-only legal document text - awaiting a professional Urdu / Roman Urdu translation, see docs/legal_translation_exclusions.md |
| `lib/core/presentation/pages/privacy_policy_page.dart` | 160 | `With Workers` | Approved English-only legal document text - awaiting a professional Urdu / Roman Urdu translation, see docs/legal_translation_exclusions.md |
| `lib/core/presentation/pages/privacy_policy_page.dart` | 161 | `Clients\' name, location (for the booking), and job details are shared with the assigne...` | Approved English-only legal document text - awaiting a professional Urdu / Roman Urdu translation, see docs/legal_translation_exclusions.md |
| `lib/core/presentation/pages/privacy_policy_page.dart` | 165 | `With Clients` | Approved English-only legal document text - awaiting a professional Urdu / Roman Urdu translation, see docs/legal_translation_exclusions.md |
| `lib/core/presentation/pages/privacy_policy_page.dart` | 166 | `Workers\' name and professional profile are shared with clients who request a service.` | Approved English-only legal document text - awaiting a professional Urdu / Roman Urdu translation, see docs/legal_translation_exclusions.md |
| `lib/core/presentation/pages/privacy_policy_page.dart` | 170 | `Service Providers` | Approved English-only legal document text - awaiting a professional Urdu / Roman Urdu translation, see docs/legal_translation_exclusions.md |
| `lib/core/presentation/pages/privacy_policy_page.dart` | 171 | `We use trusted third-party services (e.g., Firebase, cloud storage) that may process yo...` | Approved English-only legal document text - awaiting a professional Urdu / Roman Urdu translation, see docs/legal_translation_exclusions.md |
| `lib/core/presentation/pages/privacy_policy_page.dart` | 175 | `Legal Requirements` | Approved English-only legal document text - awaiting a professional Urdu / Roman Urdu translation, see docs/legal_translation_exclusions.md |
| `lib/core/presentation/pages/privacy_policy_page.dart` | 176 | `We may disclose your information if required to do so by law or in response to a valid ...` | Approved English-only legal document text - awaiting a professional Urdu / Roman Urdu translation, see docs/legal_translation_exclusions.md |
| `lib/core/presentation/pages/privacy_policy_page.dart` | 181 | `We retain your account data for as long as your account is active. ` | Approved English-only legal document text - awaiting a professional Urdu / Roman Urdu translation, see docs/legal_translation_exclusions.md |
| `lib/core/presentation/pages/privacy_policy_page.dart` | 189 | `You have the right to access, correct, or request deletion of your ` | Approved English-only legal document text - awaiting a professional Urdu / Roman Urdu translation, see docs/legal_translation_exclusions.md |
| `lib/core/presentation/pages/privacy_policy_page.dart` | 196 | `We may update this Privacy Policy from time to time. When we do, ` | Approved English-only legal document text - awaiting a professional Urdu / Roman Urdu translation, see docs/legal_translation_exclusions.md |
| `lib/core/presentation/pages/privacy_policy_page.dart` | 203 | `If you have questions about this Privacy Policy or how we handle ` | Approved English-only legal document text - awaiting a professional Urdu / Roman Urdu translation, see docs/legal_translation_exclusions.md |
| `lib/core/presentation/pages/privacy_policy_page.dart` | 222 | `Last updated: $date` | Approved English-only legal document text - awaiting a professional Urdu / Roman Urdu translation, see docs/legal_translation_exclusions.md |
| `lib/core/presentation/pages/privacy_policy_page.dart` | 302 | `$title: ` | Approved English-only legal document text - awaiting a professional Urdu / Roman Urdu translation, see docs/legal_translation_exclusions.md |
| `lib/core/presentation/pages/privacy_policy_page.dart` | 303 | `$title: ` | Approved English-only legal document text - awaiting a professional Urdu / Roman Urdu translation, see docs/legal_translation_exclusions.md |
| `lib/core/presentation/pages/terms_conditions_page.dart` | 73 | `April 2025` | Approved English-only legal document text - awaiting a professional Urdu / Roman Urdu translation, see docs/legal_translation_exclusions.md |
| `lib/core/presentation/pages/terms_conditions_page.dart` | 75 | `Welcome to EasyRepair. By creating an account or using our ` | Approved English-only legal document text - awaiting a professional Urdu / Roman Urdu translation, see docs/legal_translation_exclusions.md |
| `lib/core/presentation/pages/terms_conditions_page.dart` | 82 | `EasyRepair is an on-demand service marketplace that connects ` | Approved English-only legal document text - awaiting a professional Urdu / Roman Urdu translation, see docs/legal_translation_exclusions.md |
| `lib/core/presentation/pages/terms_conditions_page.dart` | 92 | `You must be at least 18 years of age to register and use EasyRepair. ` | Approved English-only legal document text - awaiting a professional Urdu / Roman Urdu translation, see docs/legal_translation_exclusions.md |
| `lib/core/presentation/pages/terms_conditions_page.dart` | 101 | `Provide accurate service descriptions and location details when creating a booking.` | Approved English-only legal document text - awaiting a professional Urdu / Roman Urdu translation, see docs/legal_translation_exclusions.md |
| `lib/core/presentation/pages/terms_conditions_page.dart` | 105 | `Be available at the agreed location and time when a worker is dispatched.` | Approved English-only legal document text - awaiting a professional Urdu / Roman Urdu translation, see docs/legal_translation_exclusions.md |
| `lib/core/presentation/pages/terms_conditions_page.dart` | 109 | `Treat workers with respect and professionalism. Abusive or threatening behaviour will r...` | Approved English-only legal document text - awaiting a professional Urdu / Roman Urdu translation, see docs/legal_translation_exclusions.md |
| `lib/core/presentation/pages/terms_conditions_page.dart` | 113 | `Ensure that media or attachments uploaded to the platform are relevant to the service r...` | Approved English-only legal document text - awaiting a professional Urdu / Roman Urdu translation, see docs/legal_translation_exclusions.md |
| `lib/core/presentation/pages/terms_conditions_page.dart` | 119 | `Provide truthful professional credentials during registration and verification.` | Approved English-only legal document text - awaiting a professional Urdu / Roman Urdu translation, see docs/legal_translation_exclusions.md |
| `lib/core/presentation/pages/terms_conditions_page.dart` | 123 | `Accept or decline booking requests promptly within the allocated response window.` | Approved English-only legal document text - awaiting a professional Urdu / Roman Urdu translation, see docs/legal_translation_exclusions.md |
| `lib/core/presentation/pages/terms_conditions_page.dart` | 127 | `Perform services diligently, professionally, and in accordance with applicable safety s...` | Approved English-only legal document text - awaiting a professional Urdu / Roman Urdu translation, see docs/legal_translation_exclusions.md |
| `lib/core/presentation/pages/terms_conditions_page.dart` | 131 | `Treat clients with respect and professionalism at all times.` | Approved English-only legal document text - awaiting a professional Urdu / Roman Urdu translation, see docs/legal_translation_exclusions.md |
| `lib/core/presentation/pages/terms_conditions_page.dart` | 135 | `Keep your availability status accurate and update it promptly when unavailable.` | Approved English-only legal document text - awaiting a professional Urdu / Roman Urdu translation, see docs/legal_translation_exclusions.md |
| `lib/core/presentation/pages/terms_conditions_page.dart` | 140 | `Clients may create bookings for available services. Workers may ` | Approved English-only legal document text - awaiting a professional Urdu / Roman Urdu translation, see docs/legal_translation_exclusions.md |
| `lib/core/presentation/pages/terms_conditions_page.dart` | 147 | `Bookings may be cancelled by the client or, under certain ` | Approved English-only legal document text - awaiting a professional Urdu / Roman Urdu translation, see docs/legal_translation_exclusions.md |
| `lib/core/presentation/pages/terms_conditions_page.dart` | 156 | `Pricing and payment terms for services are established between ` | Approved English-only legal document text - awaiting a professional Urdu / Roman Urdu translation, see docs/legal_translation_exclusions.md |
| `lib/core/presentation/pages/terms_conditions_page.dart` | 166 | `The following actions are strictly prohibited on EasyRepair:` | Approved English-only legal document text - awaiting a professional Urdu / Roman Urdu translation, see docs/legal_translation_exclusions.md |
| `lib/core/presentation/pages/terms_conditions_page.dart` | 171 | `Creating fake or duplicate accounts.` | Approved English-only legal document text - awaiting a professional Urdu / Roman Urdu translation, see docs/legal_translation_exclusions.md |
| `lib/core/presentation/pages/terms_conditions_page.dart` | 175 | `Submitting fraudulent or misleading service requests or reviews.` | Approved English-only legal document text - awaiting a professional Urdu / Roman Urdu translation, see docs/legal_translation_exclusions.md |
| `lib/core/presentation/pages/terms_conditions_page.dart` | 179 | `Sharing contact information to conduct transactions outside the platform in order to av...` | Approved English-only legal document text - awaiting a professional Urdu / Roman Urdu translation, see docs/legal_translation_exclusions.md |
| `lib/core/presentation/pages/terms_conditions_page.dart` | 183 | `Uploading illegal, offensive, or harmful content via chat or attachments.` | Approved English-only legal document text - awaiting a professional Urdu / Roman Urdu translation, see docs/legal_translation_exclusions.md |
| `lib/core/presentation/pages/terms_conditions_page.dart` | 187 | `Harassing, threatening, or discriminating against any other user.` | Approved English-only legal document text - awaiting a professional Urdu / Roman Urdu translation, see docs/legal_translation_exclusions.md |
| `lib/core/presentation/pages/terms_conditions_page.dart` | 192 | `EasyRepair reserves the right to suspend or permanently terminate ` | Approved English-only legal document text - awaiting a professional Urdu / Roman Urdu translation, see docs/legal_translation_exclusions.md |
| `lib/core/presentation/pages/terms_conditions_page.dart` | 202 | `EasyRepair provides the platform on an "as is" and "as available" ` | Approved English-only legal document text - awaiting a professional Urdu / Roman Urdu translation, see docs/legal_translation_exclusions.md |
| `lib/core/presentation/pages/terms_conditions_page.dart` | 213 | `In the event of a dispute between a client and a worker, ` | Approved English-only legal document text - awaiting a professional Urdu / Roman Urdu translation, see docs/legal_translation_exclusions.md |
| `lib/core/presentation/pages/terms_conditions_page.dart` | 222 | `EasyRepair may update these Terms and Conditions at any time. ` | Approved English-only legal document text - awaiting a professional Urdu / Roman Urdu translation, see docs/legal_translation_exclusions.md |
| `lib/core/presentation/pages/terms_conditions_page.dart` | 230 | `These Terms are governed by the applicable laws of the ` | Approved English-only legal document text - awaiting a professional Urdu / Roman Urdu translation, see docs/legal_translation_exclusions.md |
| `lib/core/presentation/pages/terms_conditions_page.dart` | 251 | `Last updated: $date` | Approved English-only legal document text - awaiting a professional Urdu / Roman Urdu translation, see docs/legal_translation_exclusions.md |

## Full listing

| File | Line | Literal | Category | Reason |
|---|---|---|---|---|
| `lib/firebase_options.dart` | 44 | `AIzaSyDoapEM5k8MpIkYx4XaXHick5JLhHac2X8` | 3 | Generated Firebase configuration value (FlutterFire CLI) - an API key, app/sender/project id, bucket or bundle identifier, never displayed |
| `lib/firebase_options.dart` | 45 | `1:1044296974145:web:6cda86f83652b87c6a6bc0` | 3 | Generated Firebase configuration value (FlutterFire CLI) - an API key, app/sender/project id, bucket or bundle identifier, never displayed |
| `lib/firebase_options.dart` | 47 | `easyrepair-12` | 3 | Generated Firebase configuration value (FlutterFire CLI) - an API key, app/sender/project id, bucket or bundle identifier, never displayed |
| `lib/firebase_options.dart` | 48 | `easyrepair-12.firebaseapp.com` | 3 | Generated Firebase configuration value (FlutterFire CLI) - an API key, app/sender/project id, bucket or bundle identifier, never displayed |
| `lib/firebase_options.dart` | 49 | `easyrepair-12.firebasestorage.app` | 3 | Generated Firebase configuration value (FlutterFire CLI) - an API key, app/sender/project id, bucket or bundle identifier, never displayed |
| `lib/firebase_options.dart` | 50 | `G-VG3628263W` | 3 | Generated Firebase configuration value (FlutterFire CLI) - an API key, app/sender/project id, bucket or bundle identifier, never displayed |
| `lib/firebase_options.dart` | 54 | `AIzaSyBlse5JuMQ9PFLWQViFCgnrTcAsRvUcCPc` | 3 | Generated Firebase configuration value (FlutterFire CLI) - an API key, app/sender/project id, bucket or bundle identifier, never displayed |
| `lib/firebase_options.dart` | 55 | `1:1044296974145:android:39eebc22f2eb6d246a6bc0` | 3 | Generated Firebase configuration value (FlutterFire CLI) - an API key, app/sender/project id, bucket or bundle identifier, never displayed |
| `lib/firebase_options.dart` | 57 | `easyrepair-12` | 3 | Generated Firebase configuration value (FlutterFire CLI) - an API key, app/sender/project id, bucket or bundle identifier, never displayed |
| `lib/firebase_options.dart` | 58 | `easyrepair-12.firebasestorage.app` | 3 | Generated Firebase configuration value (FlutterFire CLI) - an API key, app/sender/project id, bucket or bundle identifier, never displayed |
| `lib/firebase_options.dart` | 62 | `AIzaSyA2chCLmk6qHtcx0FxepkIV2Ux0RXijhvY` | 3 | Generated Firebase configuration value (FlutterFire CLI) - an API key, app/sender/project id, bucket or bundle identifier, never displayed |
| `lib/firebase_options.dart` | 63 | `1:1044296974145:ios:352ea81e1db964a26a6bc0` | 3 | Generated Firebase configuration value (FlutterFire CLI) - an API key, app/sender/project id, bucket or bundle identifier, never displayed |
| `lib/firebase_options.dart` | 65 | `easyrepair-12` | 3 | Generated Firebase configuration value (FlutterFire CLI) - an API key, app/sender/project id, bucket or bundle identifier, never displayed |
| `lib/firebase_options.dart` | 66 | `easyrepair-12.firebasestorage.app` | 3 | Generated Firebase configuration value (FlutterFire CLI) - an API key, app/sender/project id, bucket or bundle identifier, never displayed |
| `lib/firebase_options.dart` | 67 | `com.example.easyrepairApp` | 3 | Generated Firebase configuration value (FlutterFire CLI) - an API key, app/sender/project id, bucket or bundle identifier, never displayed |
| `lib/firebase_options.dart` | 71 | `AIzaSyA2chCLmk6qHtcx0FxepkIV2Ux0RXijhvY` | 3 | Generated Firebase configuration value (FlutterFire CLI) - an API key, app/sender/project id, bucket or bundle identifier, never displayed |
| `lib/firebase_options.dart` | 72 | `1:1044296974145:ios:352ea81e1db964a26a6bc0` | 3 | Generated Firebase configuration value (FlutterFire CLI) - an API key, app/sender/project id, bucket or bundle identifier, never displayed |
| `lib/firebase_options.dart` | 74 | `easyrepair-12` | 3 | Generated Firebase configuration value (FlutterFire CLI) - an API key, app/sender/project id, bucket or bundle identifier, never displayed |
| `lib/firebase_options.dart` | 75 | `easyrepair-12.firebasestorage.app` | 3 | Generated Firebase configuration value (FlutterFire CLI) - an API key, app/sender/project id, bucket or bundle identifier, never displayed |
| `lib/firebase_options.dart` | 76 | `com.example.easyrepairApp` | 3 | Generated Firebase configuration value (FlutterFire CLI) - an API key, app/sender/project id, bucket or bundle identifier, never displayed |
| `lib/firebase_options.dart` | 80 | `AIzaSyDoapEM5k8MpIkYx4XaXHick5JLhHac2X8` | 3 | Generated Firebase configuration value (FlutterFire CLI) - an API key, app/sender/project id, bucket or bundle identifier, never displayed |
| `lib/firebase_options.dart` | 81 | `1:1044296974145:web:35131364bda635c36a6bc0` | 3 | Generated Firebase configuration value (FlutterFire CLI) - an API key, app/sender/project id, bucket or bundle identifier, never displayed |
| `lib/firebase_options.dart` | 83 | `easyrepair-12` | 3 | Generated Firebase configuration value (FlutterFire CLI) - an API key, app/sender/project id, bucket or bundle identifier, never displayed |
| `lib/firebase_options.dart` | 84 | `easyrepair-12.firebaseapp.com` | 3 | Generated Firebase configuration value (FlutterFire CLI) - an API key, app/sender/project id, bucket or bundle identifier, never displayed |
| `lib/firebase_options.dart` | 85 | `easyrepair-12.firebasestorage.app` | 3 | Generated Firebase configuration value (FlutterFire CLI) - an API key, app/sender/project id, bucket or bundle identifier, never displayed |
| `lib/firebase_options.dart` | 86 | `G-SGPK7BRPMM` | 3 | Generated Firebase configuration value (FlutterFire CLI) - an API key, app/sender/project id, bucket or bundle identifier, never displayed |
| `lib/app/app.dart` | 424 | `EasyRepair` | 3 | Brand name - never translated |
| `lib/core/errors/dio_failure_mapper.dart` | 168 | `HTTP $statusCode${errorCode == null ? ` | 3 | Technical diagnostic (HTTP status + backend code) kept for logs (// l10n-ignore) |
| `lib/core/errors/dio_failure_mapper.dart` | 169 | ` $errorCode` | 3 | Technical diagnostic (HTTP status + backend code) kept for logs (// l10n-ignore) |
| `lib/core/errors/failures.dart` | 77 | `$runtimeType($code)` | 3 | Debug toString(), read in logs and never rendered in the UI (// l10n-ignore) |
| `lib/core/l10n/app_locale.dart` | 18 | `ur_Latn` | 3 | BCP-47 locale subtag / persisted settings value, not display copy |
| `lib/core/l10n/app_locale.dart` | 27 | `Latn` | 3 | BCP-47 locale subtag / persisted settings value, not display copy |
| `lib/core/l10n/app_locale.dart` | 34 | `English` | 3 | Language endonym in the selector - each language names itself so a user who cannot read the current language can still find their own |
| `lib/core/l10n/app_locale.dart` | 35 | `اردو` | 3 | Language endonym in the selector - each language names itself so a user who cannot read the current language can still find their own |
| `lib/core/l10n/app_locale.dart` | 36 | `Roman Urdu` | 3 | Language endonym in the selector - each language names itself so a user who cannot read the current language can still find their own |
| `lib/core/notifications/local_notification_service.dart` | 139 | `EasyRepair` | 3 | Brand name - never translated |
| `lib/core/notifications/local_notification_service.dart` | 159 | `@mipmap/ic_launcher` | 3 | Android/iOS resource reference, not display copy |
| `lib/core/presentation/pages/privacy_policy_page.dart` | 73 | `April 2025` | 5 | Approved English-only legal document text - awaiting a professional Urdu / Roman Urdu translation, see docs/legal_translation_exclusions.md |
| `lib/core/presentation/pages/privacy_policy_page.dart` | 75 | `EasyRepair ("we", "our", or "us") is committed to protecting your ` | 5 | Approved English-only legal document text - awaiting a professional Urdu / Roman Urdu translation, see docs/legal_translation_exclusions.md |
| `lib/core/presentation/pages/privacy_policy_page.dart` | 83 | `We collect the following types of information to provide and improve our services:` | 5 | Approved English-only legal document text - awaiting a professional Urdu / Roman Urdu translation, see docs/legal_translation_exclusions.md |
| `lib/core/presentation/pages/privacy_policy_page.dart` | 88 | `Account Information` | 5 | Approved English-only legal document text - awaiting a professional Urdu / Roman Urdu translation, see docs/legal_translation_exclusions.md |
| `lib/core/presentation/pages/privacy_policy_page.dart` | 89 | `When you register, we collect your full name, phone number, and password. Workers may a...` | 5 | Approved English-only legal document text - awaiting a professional Urdu / Roman Urdu translation, see docs/legal_translation_exclusions.md |
| `lib/core/presentation/pages/privacy_policy_page.dart` | 93 | `Booking & Job Details` | 5 | Approved English-only legal document text - awaiting a professional Urdu / Roman Urdu translation, see docs/legal_translation_exclusions.md |
| `lib/core/presentation/pages/privacy_policy_page.dart` | 94 | `We collect information about the services you request or provide, including job descrip...` | 5 | Approved English-only legal document text - awaiting a professional Urdu / Roman Urdu translation, see docs/legal_translation_exclusions.md |
| `lib/core/presentation/pages/privacy_policy_page.dart` | 98 | `Chat & Media` | 5 | Approved English-only legal document text - awaiting a professional Urdu / Roman Urdu translation, see docs/legal_translation_exclusions.md |
| `lib/core/presentation/pages/privacy_policy_page.dart` | 99 | `Messages, images, voice notes, and video clips exchanged through our in-app chat are st...` | 5 | Approved English-only legal document text - awaiting a professional Urdu / Roman Urdu translation, see docs/legal_translation_exclusions.md |
| `lib/core/presentation/pages/privacy_policy_page.dart` | 103 | `Location Data` | 5 | Approved English-only legal document text - awaiting a professional Urdu / Roman Urdu translation, see docs/legal_translation_exclusions.md |
| `lib/core/presentation/pages/privacy_policy_page.dart` | 108 | `Attachments` | 5 | Approved English-only legal document text - awaiting a professional Urdu / Roman Urdu translation, see docs/legal_translation_exclusions.md |
| `lib/core/presentation/pages/privacy_policy_page.dart` | 109 | `Files you attach to bookings or chat conversations (photos, videos, documents) are uplo...` | 5 | Approved English-only legal document text - awaiting a professional Urdu / Roman Urdu translation, see docs/legal_translation_exclusions.md |
| `lib/core/presentation/pages/privacy_policy_page.dart` | 114 | `We use the information we collect to:` | 5 | Approved English-only legal document text - awaiting a professional Urdu / Roman Urdu translation, see docs/legal_translation_exclusions.md |
| `lib/core/presentation/pages/privacy_policy_page.dart` | 119 | `Create and manage your account.` | 5 | Approved English-only legal document text - awaiting a professional Urdu / Roman Urdu translation, see docs/legal_translation_exclusions.md |
| `lib/core/presentation/pages/privacy_policy_page.dart` | 122 | `Match clients with suitable workers based on location and service category.` | 5 | Approved English-only legal document text - awaiting a professional Urdu / Roman Urdu translation, see docs/legal_translation_exclusions.md |
| `lib/core/presentation/pages/privacy_policy_page.dart` | 126 | `Facilitate bookings, job tracking, and in-app communication.` | 5 | Approved English-only legal document text - awaiting a professional Urdu / Roman Urdu translation, see docs/legal_translation_exclusions.md |
| `lib/core/presentation/pages/privacy_policy_page.dart` | 130 | `Send push notifications about job updates and messages.` | 5 | Approved English-only legal document text - awaiting a professional Urdu / Roman Urdu translation, see docs/legal_translation_exclusions.md |
| `lib/core/presentation/pages/privacy_policy_page.dart` | 133 | `Improve the reliability and performance of the platform.` | 5 | Approved English-only legal document text - awaiting a professional Urdu / Roman Urdu translation, see docs/legal_translation_exclusions.md |
| `lib/core/presentation/pages/privacy_policy_page.dart` | 136 | `Comply with legal obligations and enforce our Terms of Service.` | 5 | Approved English-only legal document text - awaiting a professional Urdu / Roman Urdu translation, see docs/legal_translation_exclusions.md |
| `lib/core/presentation/pages/privacy_policy_page.dart` | 145 | `Your data is stored on secure cloud servers. Access tokens are ` | 5 | Approved English-only legal document text - awaiting a professional Urdu / Roman Urdu translation, see docs/legal_translation_exclusions.md |
| `lib/core/presentation/pages/privacy_policy_page.dart` | 154 | `We do not sell your personal information to third parties. Your ` | 5 | Approved English-only legal document text - awaiting a professional Urdu / Roman Urdu translation, see docs/legal_translation_exclusions.md |
| `lib/core/presentation/pages/privacy_policy_page.dart` | 160 | `With Workers` | 5 | Approved English-only legal document text - awaiting a professional Urdu / Roman Urdu translation, see docs/legal_translation_exclusions.md |
| `lib/core/presentation/pages/privacy_policy_page.dart` | 161 | `Clients\' name, location (for the booking), and job details are shared with the assigne...` | 5 | Approved English-only legal document text - awaiting a professional Urdu / Roman Urdu translation, see docs/legal_translation_exclusions.md |
| `lib/core/presentation/pages/privacy_policy_page.dart` | 165 | `With Clients` | 5 | Approved English-only legal document text - awaiting a professional Urdu / Roman Urdu translation, see docs/legal_translation_exclusions.md |
| `lib/core/presentation/pages/privacy_policy_page.dart` | 166 | `Workers\' name and professional profile are shared with clients who request a service.` | 5 | Approved English-only legal document text - awaiting a professional Urdu / Roman Urdu translation, see docs/legal_translation_exclusions.md |
| `lib/core/presentation/pages/privacy_policy_page.dart` | 170 | `Service Providers` | 5 | Approved English-only legal document text - awaiting a professional Urdu / Roman Urdu translation, see docs/legal_translation_exclusions.md |
| `lib/core/presentation/pages/privacy_policy_page.dart` | 171 | `We use trusted third-party services (e.g., Firebase, cloud storage) that may process yo...` | 5 | Approved English-only legal document text - awaiting a professional Urdu / Roman Urdu translation, see docs/legal_translation_exclusions.md |
| `lib/core/presentation/pages/privacy_policy_page.dart` | 175 | `Legal Requirements` | 5 | Approved English-only legal document text - awaiting a professional Urdu / Roman Urdu translation, see docs/legal_translation_exclusions.md |
| `lib/core/presentation/pages/privacy_policy_page.dart` | 176 | `We may disclose your information if required to do so by law or in response to a valid ...` | 5 | Approved English-only legal document text - awaiting a professional Urdu / Roman Urdu translation, see docs/legal_translation_exclusions.md |
| `lib/core/presentation/pages/privacy_policy_page.dart` | 181 | `We retain your account data for as long as your account is active. ` | 5 | Approved English-only legal document text - awaiting a professional Urdu / Roman Urdu translation, see docs/legal_translation_exclusions.md |
| `lib/core/presentation/pages/privacy_policy_page.dart` | 189 | `You have the right to access, correct, or request deletion of your ` | 5 | Approved English-only legal document text - awaiting a professional Urdu / Roman Urdu translation, see docs/legal_translation_exclusions.md |
| `lib/core/presentation/pages/privacy_policy_page.dart` | 196 | `We may update this Privacy Policy from time to time. When we do, ` | 5 | Approved English-only legal document text - awaiting a professional Urdu / Roman Urdu translation, see docs/legal_translation_exclusions.md |
| `lib/core/presentation/pages/privacy_policy_page.dart` | 203 | `If you have questions about this Privacy Policy or how we handle ` | 5 | Approved English-only legal document text - awaiting a professional Urdu / Roman Urdu translation, see docs/legal_translation_exclusions.md |
| `lib/core/presentation/pages/privacy_policy_page.dart` | 222 | `Last updated: $date` | 5 | Approved English-only legal document text - awaiting a professional Urdu / Roman Urdu translation, see docs/legal_translation_exclusions.md |
| `lib/core/presentation/pages/privacy_policy_page.dart` | 302 | `$title: ` | 5 | Approved English-only legal document text - awaiting a professional Urdu / Roman Urdu translation, see docs/legal_translation_exclusions.md |
| `lib/core/presentation/pages/privacy_policy_page.dart` | 303 | `$title: ` | 5 | Approved English-only legal document text - awaiting a professional Urdu / Roman Urdu translation, see docs/legal_translation_exclusions.md |
| `lib/core/presentation/pages/terms_conditions_page.dart` | 73 | `April 2025` | 5 | Approved English-only legal document text - awaiting a professional Urdu / Roman Urdu translation, see docs/legal_translation_exclusions.md |
| `lib/core/presentation/pages/terms_conditions_page.dart` | 75 | `Welcome to EasyRepair. By creating an account or using our ` | 5 | Approved English-only legal document text - awaiting a professional Urdu / Roman Urdu translation, see docs/legal_translation_exclusions.md |
| `lib/core/presentation/pages/terms_conditions_page.dart` | 82 | `EasyRepair is an on-demand service marketplace that connects ` | 5 | Approved English-only legal document text - awaiting a professional Urdu / Roman Urdu translation, see docs/legal_translation_exclusions.md |
| `lib/core/presentation/pages/terms_conditions_page.dart` | 92 | `You must be at least 18 years of age to register and use EasyRepair. ` | 5 | Approved English-only legal document text - awaiting a professional Urdu / Roman Urdu translation, see docs/legal_translation_exclusions.md |
| `lib/core/presentation/pages/terms_conditions_page.dart` | 101 | `Provide accurate service descriptions and location details when creating a booking.` | 5 | Approved English-only legal document text - awaiting a professional Urdu / Roman Urdu translation, see docs/legal_translation_exclusions.md |
| `lib/core/presentation/pages/terms_conditions_page.dart` | 105 | `Be available at the agreed location and time when a worker is dispatched.` | 5 | Approved English-only legal document text - awaiting a professional Urdu / Roman Urdu translation, see docs/legal_translation_exclusions.md |
| `lib/core/presentation/pages/terms_conditions_page.dart` | 109 | `Treat workers with respect and professionalism. Abusive or threatening behaviour will r...` | 5 | Approved English-only legal document text - awaiting a professional Urdu / Roman Urdu translation, see docs/legal_translation_exclusions.md |
| `lib/core/presentation/pages/terms_conditions_page.dart` | 113 | `Ensure that media or attachments uploaded to the platform are relevant to the service r...` | 5 | Approved English-only legal document text - awaiting a professional Urdu / Roman Urdu translation, see docs/legal_translation_exclusions.md |
| `lib/core/presentation/pages/terms_conditions_page.dart` | 119 | `Provide truthful professional credentials during registration and verification.` | 5 | Approved English-only legal document text - awaiting a professional Urdu / Roman Urdu translation, see docs/legal_translation_exclusions.md |
| `lib/core/presentation/pages/terms_conditions_page.dart` | 123 | `Accept or decline booking requests promptly within the allocated response window.` | 5 | Approved English-only legal document text - awaiting a professional Urdu / Roman Urdu translation, see docs/legal_translation_exclusions.md |
| `lib/core/presentation/pages/terms_conditions_page.dart` | 127 | `Perform services diligently, professionally, and in accordance with applicable safety s...` | 5 | Approved English-only legal document text - awaiting a professional Urdu / Roman Urdu translation, see docs/legal_translation_exclusions.md |
| `lib/core/presentation/pages/terms_conditions_page.dart` | 131 | `Treat clients with respect and professionalism at all times.` | 5 | Approved English-only legal document text - awaiting a professional Urdu / Roman Urdu translation, see docs/legal_translation_exclusions.md |
| `lib/core/presentation/pages/terms_conditions_page.dart` | 135 | `Keep your availability status accurate and update it promptly when unavailable.` | 5 | Approved English-only legal document text - awaiting a professional Urdu / Roman Urdu translation, see docs/legal_translation_exclusions.md |
| `lib/core/presentation/pages/terms_conditions_page.dart` | 140 | `Clients may create bookings for available services. Workers may ` | 5 | Approved English-only legal document text - awaiting a professional Urdu / Roman Urdu translation, see docs/legal_translation_exclusions.md |
| `lib/core/presentation/pages/terms_conditions_page.dart` | 147 | `Bookings may be cancelled by the client or, under certain ` | 5 | Approved English-only legal document text - awaiting a professional Urdu / Roman Urdu translation, see docs/legal_translation_exclusions.md |
| `lib/core/presentation/pages/terms_conditions_page.dart` | 156 | `Pricing and payment terms for services are established between ` | 5 | Approved English-only legal document text - awaiting a professional Urdu / Roman Urdu translation, see docs/legal_translation_exclusions.md |
| `lib/core/presentation/pages/terms_conditions_page.dart` | 166 | `The following actions are strictly prohibited on EasyRepair:` | 5 | Approved English-only legal document text - awaiting a professional Urdu / Roman Urdu translation, see docs/legal_translation_exclusions.md |
| `lib/core/presentation/pages/terms_conditions_page.dart` | 171 | `Creating fake or duplicate accounts.` | 5 | Approved English-only legal document text - awaiting a professional Urdu / Roman Urdu translation, see docs/legal_translation_exclusions.md |
| `lib/core/presentation/pages/terms_conditions_page.dart` | 175 | `Submitting fraudulent or misleading service requests or reviews.` | 5 | Approved English-only legal document text - awaiting a professional Urdu / Roman Urdu translation, see docs/legal_translation_exclusions.md |
| `lib/core/presentation/pages/terms_conditions_page.dart` | 179 | `Sharing contact information to conduct transactions outside the platform in order to av...` | 5 | Approved English-only legal document text - awaiting a professional Urdu / Roman Urdu translation, see docs/legal_translation_exclusions.md |
| `lib/core/presentation/pages/terms_conditions_page.dart` | 183 | `Uploading illegal, offensive, or harmful content via chat or attachments.` | 5 | Approved English-only legal document text - awaiting a professional Urdu / Roman Urdu translation, see docs/legal_translation_exclusions.md |
| `lib/core/presentation/pages/terms_conditions_page.dart` | 187 | `Harassing, threatening, or discriminating against any other user.` | 5 | Approved English-only legal document text - awaiting a professional Urdu / Roman Urdu translation, see docs/legal_translation_exclusions.md |
| `lib/core/presentation/pages/terms_conditions_page.dart` | 192 | `EasyRepair reserves the right to suspend or permanently terminate ` | 5 | Approved English-only legal document text - awaiting a professional Urdu / Roman Urdu translation, see docs/legal_translation_exclusions.md |
| `lib/core/presentation/pages/terms_conditions_page.dart` | 202 | `EasyRepair provides the platform on an "as is" and "as available" ` | 5 | Approved English-only legal document text - awaiting a professional Urdu / Roman Urdu translation, see docs/legal_translation_exclusions.md |
| `lib/core/presentation/pages/terms_conditions_page.dart` | 213 | `In the event of a dispute between a client and a worker, ` | 5 | Approved English-only legal document text - awaiting a professional Urdu / Roman Urdu translation, see docs/legal_translation_exclusions.md |
| `lib/core/presentation/pages/terms_conditions_page.dart` | 222 | `EasyRepair may update these Terms and Conditions at any time. ` | 5 | Approved English-only legal document text - awaiting a professional Urdu / Roman Urdu translation, see docs/legal_translation_exclusions.md |
| `lib/core/presentation/pages/terms_conditions_page.dart` | 230 | `These Terms are governed by the applicable laws of the ` | 5 | Approved English-only legal document text - awaiting a professional Urdu / Roman Urdu translation, see docs/legal_translation_exclusions.md |
| `lib/core/presentation/pages/terms_conditions_page.dart` | 251 | `Last updated: $date` | 5 | Approved English-only legal document text - awaiting a professional Urdu / Roman Urdu translation, see docs/legal_translation_exclusions.md |
| `lib/core/utils/currency_utils.dart` | 13 | `Rs ${_pkrNumberFormat.format(amount ?? 0)}` | 3 | Currency LTR island — 'Rs' + Latin digits in every language (// l10n-ignore) |
| `lib/features/auth/presentation/login_screen.dart` | 28 | `Login API will be connected next.` | 3 | Unreachable legacy scaffold - nothing routes to or imports it |
| `lib/features/auth/presentation/login_screen.dart` | 46 | `Welcome to EasyRepair` | 3 | Unreachable legacy scaffold - nothing routes to or imports it |
| `lib/features/auth/presentation/login_screen.dart` | 51 | `Login to continue as client or worker.` | 3 | Unreachable legacy scaffold - nothing routes to or imports it |
| `lib/features/auth/presentation/login_screen.dart` | 60 | `Email` | 3 | Unreachable legacy scaffold - nothing routes to or imports it |
| `lib/features/auth/presentation/login_screen.dart` | 61 | `Enter your email` | 3 | Unreachable legacy scaffold - nothing routes to or imports it |
| `lib/features/auth/presentation/login_screen.dart` | 65 | `Email is required` | 3 | Unreachable legacy scaffold - nothing routes to or imports it |
| `lib/features/auth/presentation/login_screen.dart` | 68 | `Enter a valid email` | 3 | Unreachable legacy scaffold - nothing routes to or imports it |
| `lib/features/auth/presentation/login_screen.dart` | 78 | `Password` | 3 | Unreachable legacy scaffold - nothing routes to or imports it |
| `lib/features/auth/presentation/login_screen.dart` | 79 | `Enter your password` | 3 | Unreachable legacy scaffold - nothing routes to or imports it |
| `lib/features/auth/presentation/login_screen.dart` | 83 | `Password is required` | 3 | Unreachable legacy scaffold - nothing routes to or imports it |
| `lib/features/auth/presentation/login_screen.dart` | 86 | `Minimum 6 characters required` | 3 | Unreachable legacy scaffold - nothing routes to or imports it |
| `lib/features/auth/presentation/login_screen.dart` | 94 | `Login` | 3 | Unreachable legacy scaffold - nothing routes to or imports it |
| `lib/features/auth/presentation/login_screen.dart` | 109 | `Register` | 3 | Unreachable legacy scaffold - nothing routes to or imports it |
| `lib/features/auth/presentation/register_screen.dart` | 31 | `Register API will be connected next for $_selectedRole.` | 3 | Unreachable legacy scaffold - nothing routes to or imports it |
| `lib/features/auth/presentation/register_screen.dart` | 41 | `Create Account` | 3 | Unreachable legacy scaffold - nothing routes to or imports it |
| `lib/features/auth/presentation/register_screen.dart` | 55 | `Full Name` | 3 | Unreachable legacy scaffold - nothing routes to or imports it |
| `lib/features/auth/presentation/register_screen.dart` | 56 | `Enter your full name` | 3 | Unreachable legacy scaffold - nothing routes to or imports it |
| `lib/features/auth/presentation/register_screen.dart` | 60 | `Full name is required` | 3 | Unreachable legacy scaffold - nothing routes to or imports it |
| `lib/features/auth/presentation/register_screen.dart` | 69 | `Account Type` | 3 | Unreachable legacy scaffold - nothing routes to or imports it |
| `lib/features/auth/presentation/register_screen.dart` | 74 | `Client` | 3 | Unreachable legacy scaffold - nothing routes to or imports it |
| `lib/features/auth/presentation/register_screen.dart` | 78 | `Worker` | 3 | Unreachable legacy scaffold - nothing routes to or imports it |
| `lib/features/auth/presentation/register_screen.dart` | 94 | `Email` | 3 | Unreachable legacy scaffold - nothing routes to or imports it |
| `lib/features/auth/presentation/register_screen.dart` | 95 | `Enter your email` | 3 | Unreachable legacy scaffold - nothing routes to or imports it |
| `lib/features/auth/presentation/register_screen.dart` | 99 | `Email is required` | 3 | Unreachable legacy scaffold - nothing routes to or imports it |
| `lib/features/auth/presentation/register_screen.dart` | 102 | `Enter a valid email` | 3 | Unreachable legacy scaffold - nothing routes to or imports it |
| `lib/features/auth/presentation/register_screen.dart` | 112 | `Password` | 3 | Unreachable legacy scaffold - nothing routes to or imports it |
| `lib/features/auth/presentation/register_screen.dart` | 113 | `Create a password` | 3 | Unreachable legacy scaffold - nothing routes to or imports it |
| `lib/features/auth/presentation/register_screen.dart` | 117 | `Password is required` | 3 | Unreachable legacy scaffold - nothing routes to or imports it |
| `lib/features/auth/presentation/register_screen.dart` | 120 | `Minimum 6 characters required` | 3 | Unreachable legacy scaffold - nothing routes to or imports it |
| `lib/features/auth/presentation/register_screen.dart` | 128 | `Create Account` | 3 | Unreachable legacy scaffold - nothing routes to or imports it |
| `lib/features/auth/presentation/pages/client_forgot_password_page.dart` | 260 | `03XXXXXXXXX` | 3 | Numeric/format mask - identical in every language, stays Latin |
| `lib/features/auth/presentation/pages/client_otp_auth_page.dart` | 352 | `03XXXXXXXXX` | 3 | Numeric/format mask - identical in every language, stays Latin |
| `lib/features/auth/presentation/pages/client_otp_auth_page.dart` | 413 | `03XXXXXXXXX` | 3 | Numeric/format mask - identical in every language, stays Latin |
| `lib/features/auth/presentation/pages/forgot_password_page.dart` | 248 | `03XXXXXXXXX` | 3 | Numeric/format mask - identical in every language, stays Latin |
| `lib/features/auth/presentation/pages/role_selection_page.dart` | 60 | `Handygo` | 3 | Brand name - never translated |
| `lib/features/auth/presentation/pages/worker_login_page.dart` | 200 | `03XXXXXXXXX` | 3 | Numeric/format mask - identical in every language, stays Latin |
| `lib/features/auth/presentation/pages/worker_otp_register_page.dart` | 221 | `03XXXXXXXXX` | 3 | Numeric/format mask - identical in every language, stays Latin |
| `lib/features/auth/presentation/widgets/auth_header.dart` | 52 | `Handygo` | 3 | Brand name - never translated |
| `lib/features/auth/presentation/widgets/otp_input_section.dart` | 113 | `$minutes:$seconds` | 1 | Pure interpolation of dynamic/user/backend data |
| `lib/features/bids/domain/repositories/bid_repository.dart` | 63 | `$firstName $lastName` | 1 | Pure interpolation of dynamic/user/backend data |
| `lib/features/bids/domain/repositories/bid_repository.dart` | 64 | `${firstName.isNotEmpty ? firstName[0] : ` | 1 | Scanner cut this mid-`${...}` interpolation - dynamic content, nothing to translate |
| `lib/features/bookings/data/models/booking_model.dart` | 64 | `$base$raw` | 1 | Pure interpolation of dynamic/user/backend data |
| `lib/features/bookings/data/models/booking_model.dart` | 64 | `$base/$raw` | 1 | Pure interpolation of dynamic/user/backend data |
| `lib/features/bookings/data/models/booking_model.dart` | 347 | `Service` | 3 | Data-layer default for a backend free-text field |
| `lib/features/bookings/data/models/booking_model.dart` | 463 | `#ER-${id.substring(id.length - 6).toUpperCase()}` | 3 | Booking reference format, not translatable copy |
| `lib/features/bookings/data/models/booking_model.dart` | 464 | `#${id.toUpperCase()}` | 3 | Booking reference format, not translatable copy |
| `lib/features/bookings/data/models/inspection_report_model.dart` | 74 | `$base$raw` | 1 | Pure interpolation of dynamic/user/backend data |
| `lib/features/bookings/data/models/inspection_report_model.dart` | 74 | `$base/$raw` | 1 | Pure interpolation of dynamic/user/backend data |
| `lib/features/bookings/domain/entities/booking_entity.dart` | 365 | `Morning` | 3 | post_job_page compares this against its slot/window ids |
| `lib/features/bookings/domain/entities/booking_entity.dart` | 366 | `Afternoon` | 3 | post_job_page compares this against its slot/window ids |
| `lib/features/bookings/domain/entities/booking_entity.dart` | 367 | `Evening` | 3 | post_job_page compares this against its slot/window ids |
| `lib/features/bookings/domain/entities/booking_entity.dart` | 368 | `Night` | 3 | post_job_page compares this against its slot/window ids |
| `lib/features/bookings/domain/entities/booking_entity.dart` | 391 | `Within 1 hour` | 3 | post_job_page compares this against its slot/window ids |
| `lib/features/bookings/domain/entities/booking_entity.dart` | 392 | `Within 2 hours` | 3 | post_job_page compares this against its slot/window ids |
| `lib/features/bookings/domain/entities/booking_entity.dart` | 393 | `Within 4 hours` | 3 | post_job_page compares this against its slot/window ids |
| `lib/features/bookings/domain/entities/booking_entity.dart` | 493 | `$firstName $lastName` | 1 | Pure interpolation of dynamic/user/backend data |
| `lib/features/bookings/domain/entities/booking_entity.dart` | 494 | `${firstName.isNotEmpty ? firstName[0] : ` | 1 | Scanner cut this mid-`${...}` interpolation - dynamic content, nothing to translate |
| `lib/features/bookings/domain/entities/nearby_worker_entity.dart` | 28 | `$firstName $lastName` | 1 | Pure interpolation of dynamic/user/backend data |
| `lib/features/bookings/domain/entities/nearby_worker_entity.dart` | 30 | `${firstName.isNotEmpty ? firstName[0] : ` | 1 | Scanner cut this mid-`${...}` interpolation - dynamic content, nothing to translate |
| `lib/features/bookings/presentation/pages/booking_detail_page.dart` | 444 | `${booking.serviceEmoji}  ${booking.primaryServiceLabel}` | 1 | Pure interpolation of dynamic/user/backend data |
| `lib/features/bookings/presentation/pages/booking_detail_page.dart` | 477 | ` \u2022 ${timeSlotLabel(context.l10n, booking.timeSlot!)}` | 1 | Already localized — the literal is only a separator |
| `lib/features/bookings/presentation/pages/booking_detail_page.dart` | 2670 | `\u26a0\ufe0f` | 3 | Escaped emoji/symbol, nothing to translate |
| `lib/features/bookings/presentation/pages/my_bookings_page.dart` | 222 | `${user.firstName} ${user.lastName}` | 1 | Pure interpolation of dynamic/user/backend data |
| `lib/features/bookings/presentation/pages/my_bookings_page.dart` | 370 | `$count` | 1 | Pure interpolation of dynamic/user/backend data |
| `lib/features/bookings/presentation/utils/worker_labels.dart` | 17 | `${rating.toStringAsFixed(1)}/5` | 3 | Numeric score format, identical in every language |
| `lib/features/bookings/presentation/widgets/media_attachment_widgets.dart` | 112 | `$m:$s` | 1 | Pure interpolation of dynamic/user/backend data |
| `lib/features/bookings/presentation/widgets/media_attachment_widgets.dart` | 563 | `$m:$s` | 1 | Pure interpolation of dynamic/user/backend data |
| `lib/features/bookings/presentation/widgets/media_attachment_widgets.dart` | 620 | `${_fmt(pos)} / ${_fmt(total)}` | 1 | Pure interpolation of dynamic/user/backend data |
| `lib/features/chat/domain/entities/chat_entities.dart` | 19 | `$firstName $lastName` | 1 | Pure interpolation of dynamic/user/backend data |
| `lib/features/chat/domain/entities/chat_entities.dart` | 23 | `$f$l` | 1 | Pure interpolation of dynamic/user/backend data |
| `lib/features/chat/presentation/pages/chat_detail_page.dart` | 1334 | `$h:$m` | 1 | Pure interpolation of dynamic/user/backend data |
| `lib/features/chat/presentation/pages/chat_detail_page.dart` | 1417 | `${context.l10n.chatEdited}  ` | 1 | Already localized — the literal is only a separator |
| `lib/features/chat/presentation/pages/chat_detail_page.dart` | 1813 | `$m:$s` | 1 | Pure interpolation of dynamic/user/backend data |
| `lib/features/chat/presentation/pages/chat_detail_page.dart` | 2309 | `$m:$s` | 1 | Pure interpolation of dynamic/user/backend data |
| `lib/features/chat/presentation/pages/chat_list_page.dart` | 318 | `$unread` | 1 | Pure interpolation of dynamic/user/backend data |
| `lib/features/chat/presentation/pages/chat_list_page.dart` | 345 | `$h:$m` | 1 | Pure interpolation of dynamic/user/backend data |
| `lib/features/chat/presentation/pages/chat_list_page.dart` | 362 | `${dt.day}/${dt.month}/${dt.year % 100}` | 1 | Pure interpolation of dynamic/user/backend data |
| `lib/features/client/presentation/pages/client_home_page.dart` | 363 | `Handygo` | 3 | Brand name - never translated |
| `lib/features/client/presentation/pages/client_home_page.dart` | 471 | `$count` | 1 | Pure interpolation of dynamic/user/backend data |
| `lib/features/client/presentation/pages/client_profile_page.dart` | 32 | `client_avatar_path_$userId` | 3 | Internal identifier (switch case / map key / API parameter) |
| `lib/features/client/presentation/pages/client_profile_page.dart` | 107 | `).first}` | 3 | Filename or URL fragment, not display copy |
| `lib/features/client/presentation/pages/client_profile_page.dart` | 107 | `.${url.split(` | 3 | Filename or URL fragment, not display copy |
| `lib/features/client/presentation/pages/client_profile_page.dart` | 107 | `.jpg` | 3 | Filename or URL fragment, not display copy |
| `lib/features/client/presentation/pages/client_profile_page.dart` | 159 | `avatar.jpg` | 3 | Filename or URL fragment, not display copy |
| `lib/features/client/presentation/pages/general_info_page.dart` | 24 | `General` | 3 | Unreachable legacy scaffold - nothing routes to or imports it |
| `lib/features/client/presentation/pages/general_info_page.dart` | 39 | `Account Info` | 3 | Unreachable legacy scaffold - nothing routes to or imports it |
| `lib/features/client/presentation/pages/general_info_page.dart` | 44 | `First Name` | 3 | Unreachable legacy scaffold - nothing routes to or imports it |
| `lib/features/client/presentation/pages/general_info_page.dart` | 49 | `Last Name` | 3 | Unreachable legacy scaffold - nothing routes to or imports it |
| `lib/features/client/presentation/pages/general_info_page.dart` | 54 | `Phone Number` | 3 | Unreachable legacy scaffold - nothing routes to or imports it |
| `lib/features/client/presentation/pages/general_info_page.dart` | 62 | `Name and phone are managed by your account and cannot be changed here.` | 3 | Unreachable legacy scaffold - nothing routes to or imports it |
| `lib/features/client/presentation/pages/general_info_page.dart` | 68 | `Security` | 3 | Unreachable legacy scaffold - nothing routes to or imports it |
| `lib/features/client/presentation/pages/general_info_page.dart` | 74 | `Change Password` | 3 | Unreachable legacy scaffold - nothing routes to or imports it |
| `lib/features/client/presentation/pages/general_info_page.dart` | 134 | `Change Password` | 3 | Unreachable legacy scaffold - nothing routes to or imports it |
| `lib/features/client/presentation/pages/general_info_page.dart` | 152 | `Current Password` | 3 | Unreachable legacy scaffold - nothing routes to or imports it |
| `lib/features/client/presentation/pages/general_info_page.dart` | 160 | `New Password` | 3 | Unreachable legacy scaffold - nothing routes to or imports it |
| `lib/features/client/presentation/pages/general_info_page.dart` | 167 | `Confirm New Password` | 3 | Unreachable legacy scaffold - nothing routes to or imports it |
| `lib/features/client/presentation/pages/general_info_page.dart` | 173 | `Password change via in-app flow coming soon. Contact support if you need immediate assi...` | 3 | Unreachable legacy scaffold - nothing routes to or imports it |
| `lib/features/client/presentation/pages/general_info_page.dart` | 191 | `Update Password` | 3 | Unreachable legacy scaffold - nothing routes to or imports it |
| `lib/features/client/presentation/pages/post_job_page.dart` | 398 | `gallery_image` | 3 | Internal identifier (switch case / map key / API parameter) |
| `lib/features/client/presentation/pages/post_job_page.dart` | 403 | `gallery_video` | 3 | Internal identifier (switch case / map key / API parameter) |
| `lib/features/client/presentation/pages/post_job_page.dart` | 416 | `camera_photo` | 3 | Internal identifier (switch case / map key / API parameter) |
| `lib/features/client/presentation/pages/post_job_page.dart` | 421 | `camera_video` | 3 | Internal identifier (switch case / map key / API parameter) |
| `lib/features/client/presentation/pages/post_job_page.dart` | 490 | `${key.substring(0, 4)}...${key.substring(key.length - 4)}` | 1 | Pure interpolation of dynamic/user/backend data |
| `lib/features/client/presentation/pages/post_job_page.dart` | 497 | `${key.substring(0, 4)}...${key.substring(key.length - 4)}` | 1 | Pure interpolation of dynamic/user/backend data |
| `lib/features/client/presentation/pages/post_job_page.dart` | 657 | `$m:${sec.toString().padLeft(2, ` | 3 | Numeric time format (mm:ss), identical in every language |
| `lib/features/client/presentation/pages/post_job_page.dart` | 2841 | `$n` | 1 | Pure interpolation of dynamic/user/backend data |
| `lib/features/client/presentation/pages/post_job_page.dart` | 3476 | `${i + 1}` | 1 | Pure interpolation of dynamic/user/backend data |
| `lib/features/client/presentation/pages/privacy_policy_page.dart` | 19 | `Privacy Policy` | 3 | Unreachable legacy scaffold - nothing routes to or imports it |
| `lib/features/client/presentation/pages/privacy_policy_page.dart` | 45 | `April 2025` | 3 | Unreachable legacy scaffold - nothing routes to or imports it |
| `lib/features/client/presentation/pages/privacy_policy_page.dart` | 47 | `EasyRepair ("we", "our", or "us") is committed to protecting your ` | 3 | Unreachable legacy scaffold - nothing routes to or imports it |
| `lib/features/client/presentation/pages/privacy_policy_page.dart` | 55 | `We collect the following types of information to provide and improve our services:` | 3 | Unreachable legacy scaffold - nothing routes to or imports it |
| `lib/features/client/presentation/pages/privacy_policy_page.dart` | 60 | `Account Information` | 3 | Unreachable legacy scaffold - nothing routes to or imports it |
| `lib/features/client/presentation/pages/privacy_policy_page.dart` | 61 | `When you register, we collect your full name, phone number, and password. Workers may a...` | 3 | Unreachable legacy scaffold - nothing routes to or imports it |
| `lib/features/client/presentation/pages/privacy_policy_page.dart` | 65 | `Booking & Job Details` | 3 | Unreachable legacy scaffold - nothing routes to or imports it |
| `lib/features/client/presentation/pages/privacy_policy_page.dart` | 66 | `We collect information about the services you request or provide, including job descrip...` | 3 | Unreachable legacy scaffold - nothing routes to or imports it |
| `lib/features/client/presentation/pages/privacy_policy_page.dart` | 70 | `Chat & Media` | 3 | Unreachable legacy scaffold - nothing routes to or imports it |
| `lib/features/client/presentation/pages/privacy_policy_page.dart` | 71 | `Messages, images, voice notes, and video clips exchanged through our in-app chat are st...` | 3 | Unreachable legacy scaffold - nothing routes to or imports it |
| `lib/features/client/presentation/pages/privacy_policy_page.dart` | 75 | `Location Data` | 3 | Unreachable legacy scaffold - nothing routes to or imports it |
| `lib/features/client/presentation/pages/privacy_policy_page.dart` | 80 | `Attachments` | 3 | Unreachable legacy scaffold - nothing routes to or imports it |
| `lib/features/client/presentation/pages/privacy_policy_page.dart` | 81 | `Files you attach to bookings or chat conversations (photos, videos, documents) are uplo...` | 3 | Unreachable legacy scaffold - nothing routes to or imports it |
| `lib/features/client/presentation/pages/privacy_policy_page.dart` | 86 | `We use the information we collect to:` | 3 | Unreachable legacy scaffold - nothing routes to or imports it |
| `lib/features/client/presentation/pages/privacy_policy_page.dart` | 91 | `Create and manage your account.` | 3 | Unreachable legacy scaffold - nothing routes to or imports it |
| `lib/features/client/presentation/pages/privacy_policy_page.dart` | 94 | `Match clients with suitable workers based on location and service category.` | 3 | Unreachable legacy scaffold - nothing routes to or imports it |
| `lib/features/client/presentation/pages/privacy_policy_page.dart` | 98 | `Facilitate bookings, job tracking, and in-app communication.` | 3 | Unreachable legacy scaffold - nothing routes to or imports it |
| `lib/features/client/presentation/pages/privacy_policy_page.dart` | 102 | `Send push notifications about job updates and messages.` | 3 | Unreachable legacy scaffold - nothing routes to or imports it |
| `lib/features/client/presentation/pages/privacy_policy_page.dart` | 105 | `Improve the reliability and performance of the platform.` | 3 | Unreachable legacy scaffold - nothing routes to or imports it |
| `lib/features/client/presentation/pages/privacy_policy_page.dart` | 108 | `Comply with legal obligations and enforce our Terms of Service.` | 3 | Unreachable legacy scaffold - nothing routes to or imports it |
| `lib/features/client/presentation/pages/privacy_policy_page.dart` | 117 | `Your data is stored on secure cloud servers. Access tokens are ` | 3 | Unreachable legacy scaffold - nothing routes to or imports it |
| `lib/features/client/presentation/pages/privacy_policy_page.dart` | 126 | `We do not sell your personal information to third parties. Your ` | 3 | Unreachable legacy scaffold - nothing routes to or imports it |
| `lib/features/client/presentation/pages/privacy_policy_page.dart` | 132 | `With Workers` | 3 | Unreachable legacy scaffold - nothing routes to or imports it |
| `lib/features/client/presentation/pages/privacy_policy_page.dart` | 133 | `Clients\' name, location (for the booking), and job details are shared with the assigne...` | 3 | Unreachable legacy scaffold - nothing routes to or imports it |
| `lib/features/client/presentation/pages/privacy_policy_page.dart` | 137 | `With Clients` | 3 | Unreachable legacy scaffold - nothing routes to or imports it |
| `lib/features/client/presentation/pages/privacy_policy_page.dart` | 138 | `Workers\' name and professional profile are shared with clients who request a service.` | 3 | Unreachable legacy scaffold - nothing routes to or imports it |
| `lib/features/client/presentation/pages/privacy_policy_page.dart` | 142 | `Service Providers` | 3 | Unreachable legacy scaffold - nothing routes to or imports it |
| `lib/features/client/presentation/pages/privacy_policy_page.dart` | 143 | `We use trusted third-party services (e.g., Firebase, cloud storage) that may process yo...` | 3 | Unreachable legacy scaffold - nothing routes to or imports it |
| `lib/features/client/presentation/pages/privacy_policy_page.dart` | 147 | `Legal Requirements` | 3 | Unreachable legacy scaffold - nothing routes to or imports it |
| `lib/features/client/presentation/pages/privacy_policy_page.dart` | 148 | `We may disclose your information if required to do so by law or in response to a valid ...` | 3 | Unreachable legacy scaffold - nothing routes to or imports it |
| `lib/features/client/presentation/pages/privacy_policy_page.dart` | 153 | `We retain your account data for as long as your account is active. ` | 3 | Unreachable legacy scaffold - nothing routes to or imports it |
| `lib/features/client/presentation/pages/privacy_policy_page.dart` | 161 | `You have the right to access, correct, or request deletion of your ` | 3 | Unreachable legacy scaffold - nothing routes to or imports it |
| `lib/features/client/presentation/pages/privacy_policy_page.dart` | 168 | `We may update this Privacy Policy from time to time. When we do, ` | 3 | Unreachable legacy scaffold - nothing routes to or imports it |
| `lib/features/client/presentation/pages/privacy_policy_page.dart` | 175 | `If you have questions about this Privacy Policy or how we handle ` | 3 | Unreachable legacy scaffold - nothing routes to or imports it |
| `lib/features/client/presentation/pages/privacy_policy_page.dart` | 194 | `Last updated: $date` | 3 | Unreachable legacy scaffold - nothing routes to or imports it |
| `lib/features/client/presentation/pages/privacy_policy_page.dart` | 274 | `$title: ` | 3 | Unreachable legacy scaffold - nothing routes to or imports it |
| `lib/features/client/presentation/pages/privacy_policy_page.dart` | 275 | `$title: ` | 3 | Unreachable legacy scaffold - nothing routes to or imports it |
| `lib/features/client/presentation/pages/terms_conditions_page.dart` | 19 | `Terms & Conditions` | 3 | Unreachable legacy scaffold - nothing routes to or imports it |
| `lib/features/client/presentation/pages/terms_conditions_page.dart` | 45 | `April 2025` | 3 | Unreachable legacy scaffold - nothing routes to or imports it |
| `lib/features/client/presentation/pages/terms_conditions_page.dart` | 47 | `Welcome to EasyRepair. By creating an account or using our ` | 3 | Unreachable legacy scaffold - nothing routes to or imports it |
| `lib/features/client/presentation/pages/terms_conditions_page.dart` | 54 | `EasyRepair is an on-demand service marketplace that connects ` | 3 | Unreachable legacy scaffold - nothing routes to or imports it |
| `lib/features/client/presentation/pages/terms_conditions_page.dart` | 64 | `You must be at least 18 years of age to register and use EasyRepair. ` | 3 | Unreachable legacy scaffold - nothing routes to or imports it |
| `lib/features/client/presentation/pages/terms_conditions_page.dart` | 73 | `Provide accurate service descriptions and location details when creating a booking.` | 3 | Unreachable legacy scaffold - nothing routes to or imports it |
| `lib/features/client/presentation/pages/terms_conditions_page.dart` | 77 | `Be available at the agreed location and time when a worker is dispatched.` | 3 | Unreachable legacy scaffold - nothing routes to or imports it |
| `lib/features/client/presentation/pages/terms_conditions_page.dart` | 81 | `Treat workers with respect and professionalism. Abusive or threatening behaviour will r...` | 3 | Unreachable legacy scaffold - nothing routes to or imports it |
| `lib/features/client/presentation/pages/terms_conditions_page.dart` | 85 | `Ensure that media or attachments uploaded to the platform are relevant to the service r...` | 3 | Unreachable legacy scaffold - nothing routes to or imports it |
| `lib/features/client/presentation/pages/terms_conditions_page.dart` | 91 | `Provide truthful professional credentials during registration and verification.` | 3 | Unreachable legacy scaffold - nothing routes to or imports it |
| `lib/features/client/presentation/pages/terms_conditions_page.dart` | 95 | `Accept or decline booking requests promptly within the allocated response window.` | 3 | Unreachable legacy scaffold - nothing routes to or imports it |
| `lib/features/client/presentation/pages/terms_conditions_page.dart` | 99 | `Perform services diligently, professionally, and in accordance with applicable safety s...` | 3 | Unreachable legacy scaffold - nothing routes to or imports it |
| `lib/features/client/presentation/pages/terms_conditions_page.dart` | 103 | `Treat clients with respect and professionalism at all times.` | 3 | Unreachable legacy scaffold - nothing routes to or imports it |
| `lib/features/client/presentation/pages/terms_conditions_page.dart` | 107 | `Keep your availability status accurate and update it promptly when unavailable.` | 3 | Unreachable legacy scaffold - nothing routes to or imports it |
| `lib/features/client/presentation/pages/terms_conditions_page.dart` | 112 | `Clients may create bookings for available services. Workers may ` | 3 | Unreachable legacy scaffold - nothing routes to or imports it |
| `lib/features/client/presentation/pages/terms_conditions_page.dart` | 119 | `Bookings may be cancelled by the client or, under certain ` | 3 | Unreachable legacy scaffold - nothing routes to or imports it |
| `lib/features/client/presentation/pages/terms_conditions_page.dart` | 128 | `Pricing and payment terms for services are established between ` | 3 | Unreachable legacy scaffold - nothing routes to or imports it |
| `lib/features/client/presentation/pages/terms_conditions_page.dart` | 138 | `The following actions are strictly prohibited on EasyRepair:` | 3 | Unreachable legacy scaffold - nothing routes to or imports it |
| `lib/features/client/presentation/pages/terms_conditions_page.dart` | 143 | `Creating fake or duplicate accounts.` | 3 | Unreachable legacy scaffold - nothing routes to or imports it |
| `lib/features/client/presentation/pages/terms_conditions_page.dart` | 147 | `Submitting fraudulent or misleading service requests or reviews.` | 3 | Unreachable legacy scaffold - nothing routes to or imports it |
| `lib/features/client/presentation/pages/terms_conditions_page.dart` | 151 | `Sharing contact information to conduct transactions outside the platform in order to av...` | 3 | Unreachable legacy scaffold - nothing routes to or imports it |
| `lib/features/client/presentation/pages/terms_conditions_page.dart` | 155 | `Uploading illegal, offensive, or harmful content via chat or attachments.` | 3 | Unreachable legacy scaffold - nothing routes to or imports it |
| `lib/features/client/presentation/pages/terms_conditions_page.dart` | 159 | `Harassing, threatening, or discriminating against any other user.` | 3 | Unreachable legacy scaffold - nothing routes to or imports it |
| `lib/features/client/presentation/pages/terms_conditions_page.dart` | 164 | `EasyRepair reserves the right to suspend or permanently terminate ` | 3 | Unreachable legacy scaffold - nothing routes to or imports it |
| `lib/features/client/presentation/pages/terms_conditions_page.dart` | 174 | `EasyRepair provides the platform on an "as is" and "as available" ` | 3 | Unreachable legacy scaffold - nothing routes to or imports it |
| `lib/features/client/presentation/pages/terms_conditions_page.dart` | 185 | `In the event of a dispute between a client and a worker, ` | 3 | Unreachable legacy scaffold - nothing routes to or imports it |
| `lib/features/client/presentation/pages/terms_conditions_page.dart` | 194 | `EasyRepair may update these Terms and Conditions at any time. ` | 3 | Unreachable legacy scaffold - nothing routes to or imports it |
| `lib/features/client/presentation/pages/terms_conditions_page.dart` | 202 | `These Terms are governed by the applicable laws of the ` | 3 | Unreachable legacy scaffold - nothing routes to or imports it |
| `lib/features/client/presentation/pages/terms_conditions_page.dart` | 223 | `Last updated: $date` | 3 | Unreachable legacy scaffold - nothing routes to or imports it |
| `lib/features/client/presentation/widgets/location_picker_sheet.dart` | 197 | `${latlng.latitude},${latlng.longitude}` | 3 | HTTP request parameter sent to an external API |
| `lib/features/client/presentation/widgets/location_picker_sheet.dart` | 291 | `country:pk` | 3 | Internal identifier (switch case / map key / API parameter) |
| `lib/features/client/presentation/widgets/location_picker_sheet.dart` | 292 | `${_kKarachiCenter.latitude},${_kKarachiCenter.longitude}` | 3 | HTTP request parameter sent to an external API |
| `lib/features/client/presentation/widgets/location_picker_sheet.dart` | 332 | `geometry,formatted_address` | 3 | Internal identifier (switch case / map key / API parameter) |
| `lib/features/client/presentation/widgets/location_picker_sheet.dart` | 346 | `${prediction.mainText}, ${prediction.secondaryText}` | 1 | Pure interpolation of dynamic/user/backend data |
| `lib/features/client/presentation/widgets/service_data.dart` | 103 | `Beat the Karachi Heat` | 3 | Unreachable legacy scaffold - nothing routes to or imports it |
| `lib/features/client/presentation/widgets/service_data.dart` | 104 | `Beat the Karachi Heat` | 3 | Unreachable legacy scaffold - nothing routes to or imports it |
| `lib/features/client/presentation/widgets/service_data.dart` | 105 | `New Home Essentials` | 3 | Unreachable legacy scaffold - nothing routes to or imports it |
| `lib/features/client/presentation/widgets/service_data.dart` | 106 | `New Home Essentials` | 3 | Unreachable legacy scaffold - nothing routes to or imports it |
| `lib/features/client/presentation/widgets/service_data.dart` | 107 | `New Home Essentials` | 3 | Unreachable legacy scaffold - nothing routes to or imports it |
| `lib/features/client/presentation/widgets/service_data.dart` | 108 | `Home Improvement Help` | 3 | Unreachable legacy scaffold - nothing routes to or imports it |
| `lib/features/client/presentation/widgets/service_data.dart` | 109 | `Home Improvement Help` | 3 | Unreachable legacy scaffold - nothing routes to or imports it |
| `lib/features/client/presentation/widgets/service_data.dart` | 110 | `Home Improvement Help` | 3 | Unreachable legacy scaffold - nothing routes to or imports it |
| `lib/features/client/presentation/widgets/service_data.dart` | 111 | `Keep Your Home Running` | 3 | Unreachable legacy scaffold - nothing routes to or imports it |
| `lib/features/client/presentation/widgets/service_data.dart` | 112 | `Keep Your Home Running` | 3 | Unreachable legacy scaffold - nothing routes to or imports it |
| `lib/features/client/presentation/widgets/service_data.dart` | 113 | `More Services` | 3 | Unreachable legacy scaffold - nothing routes to or imports it |
| `lib/features/client/presentation/widgets/service_data.dart` | 129 | `AC Technician` | 3 | Unreachable legacy scaffold - nothing routes to or imports it |
| `lib/features/client/presentation/widgets/service_data.dart` | 137 | `Electrician` | 3 | Unreachable legacy scaffold - nothing routes to or imports it |
| `lib/features/client/presentation/widgets/service_data.dart` | 145 | `Plumber` | 3 | Unreachable legacy scaffold - nothing routes to or imports it |
| `lib/features/client/presentation/widgets/service_data.dart` | 153 | `Handyman` | 3 | Unreachable legacy scaffold - nothing routes to or imports it |
| `lib/features/client/presentation/widgets/service_data.dart` | 166 | `Beat the Karachi Heat` | 3 | Unreachable legacy scaffold - nothing routes to or imports it |
| `lib/features/client/presentation/widgets/service_data.dart` | 169 | `AC Help` | 3 | Unreachable legacy scaffold - nothing routes to or imports it |
| `lib/features/client/presentation/widgets/service_data.dart` | 177 | `Pest Control` | 3 | Unreachable legacy scaffold - nothing routes to or imports it |
| `lib/features/client/presentation/widgets/service_data.dart` | 187 | `New Home Essentials` | 3 | Unreachable legacy scaffold - nothing routes to or imports it |
| `lib/features/client/presentation/widgets/service_data.dart` | 190 | `Handyman` | 3 | Unreachable legacy scaffold - nothing routes to or imports it |
| `lib/features/client/presentation/widgets/service_data.dart` | 198 | `Deep Cleaning` | 3 | Unreachable legacy scaffold - nothing routes to or imports it |
| `lib/features/client/presentation/widgets/service_data.dart` | 206 | `Paint / Painter` | 3 | Unreachable legacy scaffold - nothing routes to or imports it |
| `lib/features/client/presentation/widgets/service_data.dart` | 216 | `Home Improvement Help` | 3 | Unreachable legacy scaffold - nothing routes to or imports it |
| `lib/features/client/presentation/widgets/service_data.dart` | 219 | `Plumbing` | 3 | Unreachable legacy scaffold - nothing routes to or imports it |
| `lib/features/client/presentation/widgets/service_data.dart` | 227 | `Electrical` | 3 | Unreachable legacy scaffold - nothing routes to or imports it |
| `lib/features/client/presentation/widgets/service_data.dart` | 235 | `Carpentry` | 3 | Unreachable legacy scaffold - nothing routes to or imports it |
| `lib/features/client/presentation/widgets/service_data.dart` | 245 | `Keep Your Home Running` | 3 | Unreachable legacy scaffold - nothing routes to or imports it |
| `lib/features/client/presentation/widgets/service_data.dart` | 248 | `Gardening` | 3 | Unreachable legacy scaffold - nothing routes to or imports it |
| `lib/features/client/presentation/widgets/service_data.dart` | 256 | `Car Wash` | 3 | Unreachable legacy scaffold - nothing routes to or imports it |
| `lib/features/worker/data/models/agreement_template_model.dart` | 21 | `Malformed $resource response: "$field" is missing or not a string. ` | 3 | Developer diagnostic carried in Failure.diagnostic, never shown (// l10n-ignore) |
| `lib/features/worker/data/models/earning_history_model.dart` | 24 | `Service` | 3 | Data-layer default for a backend free-text field |
| `lib/features/worker/data/models/worker_review_model.dart` | 27 | `Service` | 3 | Data-layer default for a backend free-text field |
| `lib/features/worker/data/repositories/worker_repository_impl.dart` | 176 | `ur_Latn` | 3 | BCP-47 locale subtag / persisted settings value, not display copy |
| `lib/features/worker/domain/entities/new_job_entity.dart` | 28 | `$firstName $lastName` | 1 | Pure interpolation of dynamic/user/backend data |
| `lib/features/worker/presentation/pages/inspection_report_form_page.dart` | 726 | `$m:$s` | 1 | Pure interpolation of dynamic/user/backend data |
| `lib/features/worker/presentation/pages/worker_bid_page.dart` | 421 | `${job.addressLine}, ${job.city}` | 1 | Pure interpolation of dynamic/user/backend data |
| `lib/features/worker/presentation/pages/worker_home_page.dart` | 295 | `$count` | 1 | Pure interpolation of dynamic/user/backend data |
| `lib/features/worker/presentation/pages/worker_home_page.dart` | 620 | `${profile.stats.completedJobs}` | 1 | Pure interpolation of dynamic/user/backend data |
| `lib/features/worker/presentation/pages/worker_home_page.dart` | 634 | `${profile.stats.activeJobs}` | 1 | Pure interpolation of dynamic/user/backend data |
| `lib/features/worker/presentation/pages/worker_home_page.dart` | 1169 | `${profile.stats.completedJobs}` | 1 | Pure interpolation of dynamic/user/backend data |
| `lib/features/worker/presentation/pages/worker_home_page.dart` | 1287 | `${profile.rating.toStringAsFixed(1)} · ${profile.totalRatings}` | 1 | Pure interpolation of dynamic/user/backend data |
| `lib/features/worker/presentation/pages/worker_job_detail_page.dart` | 372 | ` • ${timeSlotLabel(context.l10n, job.timeSlot!)}` | 1 | Already localized — the literal is only a separator |
| `lib/features/worker/presentation/pages/worker_job_detail_page.dart` | 1562 | `${origin.latitude},${origin.longitude}` | 3 | HTTP request parameter sent to an external API |
| `lib/features/worker/presentation/pages/worker_job_detail_page.dart` | 1563 | `${dest.latitude},${dest.longitude}` | 3 | HTTP request parameter sent to an external API |
| `lib/features/worker/presentation/pages/worker_jobs_page.dart` | 457 | `${job.city.isNotEmpty ? ` | 1 | Scanner cut this mid-`${...}` interpolation - dynamic content, nothing to translate |
| `lib/features/worker/presentation/pages/worker_jobs_page.dart` | 458 | `${job.city}, ` | 1 | Pure interpolation of dynamic/user/backend data |
| `lib/features/worker/presentation/pages/worker_jobs_page.dart` | 706 | `${lifecycleActionLabel(context.l10n, action)}...` | 1 | Already localized — the literal is only a separator |
| `lib/features/worker/presentation/pages/worker_jobs_page.dart` | 830 | `${inspectionActionLabel(context.l10n, action)}...` | 1 | Already localized — the literal is only a separator |
| `lib/features/worker/presentation/pages/worker_profile_completion_page.dart` | 45 | `agreement:$documentType` | 3 | Internal error-set key, matched in code and never rendered (// l10n-ignore) |
| `lib/features/worker/presentation/pages/worker_profile_completion_page.dart` | 147 | `$exp` | 1 | Pure interpolation of dynamic/user/backend data |
| `lib/features/worker/presentation/pages/worker_profile_completion_page.dart` | 328 | `${date.year.toString().padLeft(4, ` | 1 | Scanner cut this mid-`${...}` interpolation - dynamic content, nothing to translate |
| `lib/features/worker/presentation/pages/worker_profile_page.dart` | 39 | `worker_avatar_path_$userId` | 3 | Internal identifier (switch case / map key / API parameter) |
| `lib/features/worker/presentation/pages/worker_profile_page.dart` | 113 | `).first}` | 3 | Filename or URL fragment, not display copy |
| `lib/features/worker/presentation/pages/worker_profile_page.dart` | 113 | `.${url.split(` | 3 | Filename or URL fragment, not display copy |
| `lib/features/worker/presentation/pages/worker_profile_page.dart` | 113 | `.jpg` | 3 | Filename or URL fragment, not display copy |
| `lib/features/worker/presentation/pages/worker_profile_page.dart` | 165 | `avatar.jpg` | 3 | Filename or URL fragment, not display copy |
| `lib/features/worker/presentation/pages/worker_reviews_page.dart` | 175 | `$maxRating` | 1 | Pure interpolation of dynamic/user/backend data |
| `lib/features/worker/presentation/pages/worker_reviews_page.dart` | 176 | `$minRating` | 1 | Pure interpolation of dynamic/user/backend data |
| `lib/features/worker/presentation/providers/worker_providers.dart` | 140 | `initial online sync` | 3 | Sync reason sent to the /workers/location API, never displayed |
| `lib/features/worker/presentation/providers/worker_providers.dart` | 173 | `post_online_refresh` | 3 | Internal identifier (switch case / map key / API parameter) |
| `lib/features/worker/presentation/providers/worker_providers.dart` | 217 | `final offline sync` | 3 | Sync reason sent to the /workers/location API, never displayed |
| `lib/features/worker/presentation/providers/worker_providers.dart` | 259 | `app_resumed` | 3 | Internal identifier (switch case / map key / API parameter) |
| `lib/features/worker/presentation/providers/worker_providers.dart` | 309 | ` ($forcedReason)` | 3 | Developer log, never shown to a user |
| `lib/features/worker/presentation/providers/worker_providers.dart` | 310 | ` (moved ${distanceMeters!.toStringAsFixed(1)}m)` | 3 | Developer log, never shown to a user |
| `lib/features/worker/presentation/providers/worker_providers.dart` | 311 | ` (heartbeat)` | 3 | Developer log, never shown to a user |
| `lib/features/worker/presentation/providers/worker_providers.dart` | 312 | ` (backup_5m)` | 3 | Developer log, never shown to a user |
| `lib/features/worker/presentation/providers/worker_providers.dart` | 322 | `moved ${distanceMeters!.toStringAsFixed(1)}m` | 3 | Sync reason sent to the /workers/location API, never displayed |
| `lib/features/worker/presentation/providers/worker_providers.dart` | 324 | `backup_5m` | 3 | Internal identifier (switch case / map key / API parameter) |
