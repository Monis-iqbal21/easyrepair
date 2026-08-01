# Legal documents: excluded from machine translation

**Audit date: 2026-08-01**
**Category 5 count at that date: 64 strings**

HandyGo's interface ships in English, Urdu and Roman Urdu. Two documents do
**not**: the Privacy Policy and the Terms and Conditions. Their approved
English wording is what is shown in every language, and this file records why.

---

## 1. What is excluded

| File | Strings | What it holds |
|---|---|---|
| `easyrepair_app/lib/core/presentation/pages/privacy_policy_page.dart` | 36 | The approved Privacy Policy body |
| `easyrepair_app/lib/core/presentation/pages/terms_conditions_page.dart` | 28 | The approved Terms and Conditions body |
| | **64** | |

Excluded content is the *document body only*: clauses, section headings,
definitions, bullet and numbered points, and the "Last updated" date line.

The block is delimited in the source so the exclusion cannot drift:

```dart
// ── L10N-LEGAL-BODY:START ──
...the approved English text...
// ── L10N-LEGAL-BODY:END ──
```

`tool/audit_report.py` honours those markers **only** in the two files above, so
the marker cannot be used to hide ordinary UI anywhere else, and
`test/core/l10n/legal_pages_test.dart` fails if a marker is removed or if a
legal clause turns up in `app_en.arb`.

---

## 2. What *is* localized on those screens

Everything that is app chrome rather than legal content:

- the app-bar title (`settingsPrivacyPolicy`, `settingsTermsConditions`)
- the back button and page scaffolding
- the notice above the document (`legalEnglishOnlyNotice`):

| Language | Text |
|---|---|
| English | This legal document is currently available in English only. |
| Urdu | یہ قانونی دستاویز فی الحال صرف انگریزی میں دستیاب ہے۔ |
| Roman Urdu | Yeh qanooni document filhal sirf English mein available hai. |

The body is additionally wrapped in `Directionality(textDirection: ltr)`, so the
English clauses read correctly even when the rest of the app is mirrored for
Urdu.

---

## 3. Why machine translation was not used

A privacy policy and a set of terms are binding statements about data handling,
liability, cancellation and dispute resolution. A machine or non-specialist
translation of that text:

- can change the legal meaning of a clause while reading fluently;
- creates two versions of the same obligation with no stated precedence, so it
  is unclear which one governs a dispute;
- can misstate what the app does with personal and location data, which is a
  regulatory exposure, not a copy problem.

Translating the surrounding UI carries none of that risk; translating the
clauses does. So the clauses were left exactly as approved, and the user is told
plainly, in their own language, that the document is English only.

---

## 4. What is still required

**The legal documents themselves are not multilingual.** Localization of the
app is complete; localization of the Privacy Policy and Terms is not, and is
not claimed to be.

To close this out, someone with the authority to approve legal wording has to
supply:

1. a professionally translated **Urdu** Privacy Policy and Terms;
2. a professionally translated **Roman Urdu** Privacy Policy and Terms;
3. a decision on which language version governs if they ever conflict.

Only then should the bodies move into the ARB files, the
`L10N-LEGAL-BODY` markers be removed, and `legalEnglishOnlyNotice` be dropped.

---

## 5. Known related cleanup (not part of this exclusion)

Unreachable duplicates of both documents still exist at:

- `lib/features/client/presentation/pages/privacy_policy_page.dart`
- `lib/features/client/presentation/pages/terms_conditions_page.dart`

Nothing routes to or imports them — both profile screens use the
`lib/core/presentation/pages/` versions. The audit reports them as Category 3
(*unreachable legacy scaffold*), not Category 5, because they are dead code
rather than shipped legal text. They should be deleted in a separate cleanup;
until then, any change to the live documents must not be mistakenly applied to
these copies.
