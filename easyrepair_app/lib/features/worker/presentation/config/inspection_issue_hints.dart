import '../../../../l10n/app_localizations.dart';

/// Per-category example hints for the Ustaad Inspection Report form's
/// "what was the issue" textbox — add or change a hint for a specific service
/// category here. Keyed on the category's stable backend name
/// (`ServiceCategory.name`, exactly what `BookingEntity.serviceCategory`
/// carries) — never on a UI-displayed/localized label, so this can't silently
/// stop matching if wording elsewhere changes.
///
/// The keys stay raw backend names; only the hint an Ustaad reads is
/// translated, through the `inspHint*` ARB keys.
///
/// To add a new category's hint, add an entry below plus its ARB key — no
/// other code needs to change.
Map<String, String> inspectionIssueHints(AppLocalizations l10n) => {
      'Electrician': l10n.inspHintElectrical,
      'Plumber': l10n.inspHintPlumbing,
      'AC Technician': l10n.inspHintAc,
      'Carpenter': l10n.inspHintCarpentry,
    };

/// Looks up the example hint for [categoryName], falling back gracefully when
/// it is null or not present in [inspectionIssueHints] — an unknown or
/// unmapped category keeps a usable field instead of showing nothing.
String inspectionIssueHintFor(AppLocalizations l10n, String? categoryName) {
  if (categoryName == null) return l10n.inspHintFallback;
  return inspectionIssueHints(l10n)[categoryName] ?? l10n.inspHintFallback;
}
