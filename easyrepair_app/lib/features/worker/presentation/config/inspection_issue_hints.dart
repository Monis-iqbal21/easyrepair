/// Per-category example hints for the Ustaad Inspection Report form's
/// "Masla kya nikla?" textbox — edit this file to add/change a hint for a
/// specific service category. Keyed on the category's stable backend name
/// (`ServiceCategory.name`, exactly what `BookingEntity.serviceCategory`
/// carries) — never on a UI-displayed/localized label, so this can't
/// silently stop matching if wording elsewhere changes.
///
/// To add a new category's hint, just add a new entry below — no other code
/// needs to change.
const Map<String, String> inspectionIssueHints = {
  'Electrician': 'Misal: switch kharab hai, wire short hai...',
  'Plumber': 'Misal: pipe leak hai, drain block hai...',
  'AC Technician': 'Misal: AC cooling nahi kar raha, gas leak hai...',
  'Carpenter': 'Misal: darwaza theek se band nahi hota, hinge toot gaya...',
};

/// Shown when [categoryName] doesn't match any key above (unknown/unmapped
/// category) — keeps the field usable instead of showing nothing.
const String inspectionIssueHintFallback = 'e.g. Gas leak — refill zaroori';

/// Looks up the example hint for [categoryName], falling back gracefully
/// when it's null or not present in [inspectionIssueHints].
String inspectionIssueHintFor(String? categoryName) {
  if (categoryName == null) return inspectionIssueHintFallback;
  return inspectionIssueHints[categoryName] ?? inspectionIssueHintFallback;
}
