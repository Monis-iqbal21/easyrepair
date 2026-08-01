# HandyGo translations

HandyGo ships in three languages: **English**, **Urdu (اردو)** and **Roman Urdu**.
English is the default and is also the fallback whenever a translation is
missing.

---

## 1. Where the real translation files live

The app reads its strings from three ARB files. These are the source of truth:

| Language | File |
|---|---|
| English (template) | `easyrepair_app/lib/l10n/app_en.arb` |
| Urdu | `easyrepair_app/lib/l10n/app_ur.arb` |
| Roman Urdu | `easyrepair_app/lib/l10n/app_ur_Latn.arb` |

Roman Urdu uses the locale `ur_Latn` — Urdu written in Latin script. It renders
**left-to-right**, unlike Urdu script which renders right-to-left.

> ⚠️ `lib/l10n/app_localizations*.dart` are **generated**. Never edit them by
> hand — your changes will be wiped the next time anyone builds. See step 7.

---

## 2. Opening the review spreadsheet

For review and bulk editing, every string is also exported to:

```
docs/handygo_translations.csv
```

Open it in Excel, Google Sheets, LibreOffice or any CSV editor. It is saved as
UTF-8 with a BOM so Excel shows Urdu script correctly without extra steps.

To regenerate it from the current ARB files:

```bash
cd easyrepair_app
python tool/translations_csv.py export
```

---

## 3. Which columns you may edit

| Column | Editable? | Notes |
|---|---|---|
| `Key` | **No** | Identifies the string in code. See section 4. |
| `Screen/Context` | No | Derived from the key; regenerated on every export. |
| `English` | Yes | The source text and the fallback. |
| `Urdu` | Yes | Urdu script. |
| `Roman Urdu` | Yes | Latin script, Pakistani Roman Urdu. |
| `Notes` | No | Derived; regenerated on every export. |

---

## 4. Never edit the Key column

Keys are how the Dart code finds a string (`context.l10n.bookingStatusCompleted`).
Renaming one in the CSV does not rename it in the code — it breaks the build.

The sync script therefore **rejects** any key it does not recognise, any
duplicate key, and any key that has gone missing. Adding a genuinely new string
is a code change: add it to `app_en.arb`, use it in a widget, then re-export the
CSV.

---

## 5. Never remove, rename or translate placeholders

Placeholders are the `{...}` parts, for example:

```
English : Welcome, {name}!
Urdu    : خوش آمدید، {name}!
Roman   : Khush aamdeed, {name}!
```

Rules:

- Every placeholder in the English text must appear in **both** translations.
- Placeholder names are code, not words. `{name}` must stay `{name}` — never
  `{naam}`, never `{ name }`.
- You may move a placeholder to wherever the sentence needs it.
- ICU plurals must keep their structure:
  `{count, plural, =1{{count} job} other{{count} jobs}}`.

The sync script checks all of this and refuses to write if anything is off.

---

## 6. Validating and syncing the CSV back into the ARB files

```bash
cd easyrepair_app

# Check the spreadsheet without touching anything
python tool/translations_csv.py validate

# Write the CSV back into the three ARB files
python tool/translations_csv.py sync
```

`sync` validates first and **stops without modifying any ARB file** if a single
check fails, so a bad edit can never leave the three files half-updated. It
rejects:

- unknown, duplicate or missing keys
- blank English, Urdu or Roman Urdu values
- placeholders that were removed, renamed, added or translated
- unbalanced `{ }` / malformed ICU syntax

Output formatting is deterministic: syncing twice produces byte-identical files,
so a no-op sync shows no diff.

One key is intentionally exempt from the "no blanks" rule:
`l10nFallbackProbe` is deliberately left untranslated to prove that a missing
translation falls back to English.

---

## 7. Regenerating the Dart localizations

After any ARB change:

```bash
cd easyrepair_app
flutter gen-l10n
```

This rewrites `lib/l10n/app_localizations*.dart` from the ARB files. It also
prints how many messages are untranslated per locale — expect exactly **1**
(the fallback probe). Anything higher means a translation was lost.

Normal `flutter run` / `flutter build` also regenerate these files, because
`generate: true` is set in `pubspec.yaml`.

---

## 8. Running the focused localization tests

```bash
cd easyrepair_app
flutter test test/core/l10n
```

These cover language switching, persistence, RTL/LTR direction, English
fallback, ARB key parity, placeholder parity, duplicate and blank detection,
status-label localization, and the bottom-navigation protection below.

---

## 9. Bottom navigation is intentionally English

The Client and Ustaad bottom navigation bars are **excluded from localization on
purpose**. In all three languages they:

- keep their English labels (`Home`, `Bookings`, `Chats`, `Profile`, and the
  Ustaad equivalents)
- keep the same tab order, icons, routes and behaviour
- stay left-to-right, so Urdu RTL never reverses them

Those labels must not be added to any ARB file. `bottom_nav_protection_test.dart`
fails the build if they are.

---

## 10. Legal documents are English only, on purpose

The Privacy Policy and Terms and Conditions bodies are **not** translated and
must never be added to the ARB files. They stay in their approved English
wording until a professionally approved Urdu and Roman Urdu legal translation
exists; a localized notice above each document tells the reader so in their own
language.

Full reasoning, the exact exclusion list and what is still required:
[`legal_translation_exclusions.md`](legal_translation_exclusions.md).

The hard-coded string audit reports these under **Category 5**, which is a
product and legal decision — not missed migration work. Category 4 (genuinely
missed UI copy) must still be zero.

---

## 11. The hard-coded string audit

```bash
cd easyrepair_app
python tool/audit_report.py     # writes docs/localization_hardcoded_audit.md
```

Every literal found in a user-visible position is put in exactly one category,
each with a printed reason:

| Category | Meaning |
|---|---|
| 1 | Dynamic / user / backend content that must remain unchanged |
| 2 | Protected bottom-navigation English |
| 3 | Internal technical value, or a fixed name no language changes |
| 4 | **Missed app-owned visible text — must be zero** |
| 5 | Approved English-only legal document content |

The script exits non-zero while Category 4 is above zero.

There are no blanket "skip this file" rules. The two file-scoped exclusions
(generated FlutterFire config, the marked legal bodies) each require
corroborating evidence inside the file. Anything else that genuinely is not
translatable is excluded one line at a time with a mandatory reason:

```dart
// l10n-ignore: Currency LTR island — 'Rs' + Latin digits in every language
```

The reason is printed in the audit, so no exclusion can be made silently.

---

## 12. Errors are localized by code, not by string

`Failure` carries a `FailureCode`, not English copy. The Dio mapper
(`core/errors/dio_failure_mapper.dart`) decides *what* went wrong;
`core/errors/failure_messages.dart` turns that into words:

```dart
failureMessage(context.l10n, error, fallback: context.l10n.bookingCancelFailed)
```

- A human sentence written by the backend (`Failure.message`) is shown
  **verbatim** — it is not this app's copy and is never machine-translated.
- Otherwise the code is rendered from the ARB files (`error*` keys).
- `fallback` is the screen's own "this action failed" wording and is used only
  when the failure carries nothing more specific.

Raw Dio text and HTTP status codes go to `Failure.diagnostic`, which is for logs
and is never shown or translated.

---

## 13. Known gap: Android notification-channel names

`core/notifications/local_notification_service.dart` registers two Android
notification channels ("Booking Updates", "Chat Messages") and their
descriptions. Those strings appear in the **Android system settings** screen,
not in this app's widget tree.

They are still English in every language. Localizing them means loading
`AppLocalizations` outside the widget tree — the channels are registered from
`main()`, before any `BuildContext` or selected locale exists — and
re-registering both channels whenever the user switches language. That is a
notification-infrastructure change, not a copy change, so it was left out of the
in-app localization work and is recorded here instead of being quietly ignored.

Everything the app itself renders, including notification titles, bodies and the
in-app banner, is localized.

---

## 14. Do not hand-edit generated localization Dart files

`lib/l10n/app_localizations.dart`, `app_localizations_en.dart` and
`app_localizations_ur.dart` are produced by `flutter gen-l10n`. Edit the ARB
files (or the CSV) instead — anything typed into the generated files is lost on
the next build.
