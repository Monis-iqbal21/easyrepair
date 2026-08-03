import '../../../../l10n/app_localizations.dart';

/// Per-trade example hints for the Ustaad Inspection Report form.
///
/// Every example an Ustaad reads must match the trade they were booked for —
/// an Electrician being shown "Gas leak", or a part example of "Gas refill",
/// is the bug this file exists to prevent. All three example-bearing fields
/// are resolved together from one entry per trade, so adding a trade can never
/// leave one field showing another trade's examples.
///
/// Keyed on the category's stable backend name (`ServiceCategory.name`,
/// exactly what `BookingEntity.serviceCategory` carries) — never on a
/// UI-displayed/localized label, so this can't silently stop matching if
/// wording elsewhere changes.
///
/// The keys stay raw backend names; only the hints an Ustaad reads are
/// translated, through the `insp*Hint*` ARB keys.
///
/// To add a trade: add one entry below plus its three ARB keys. No other code
/// changes.
class InspectionFieldHints {
  const InspectionFieldHints({
    required this.issue,
    required this.repair,
    required this.partName,
  });

  /// "What was the issue?" — the findings / observations field.
  final String issue;

  /// "Recommended repair" — what work is needed.
  final String repair;

  /// A parts / materials / spare-parts line item.
  final String partName;
}

/// Trades with tailored examples. Anything else falls back to trade-neutral
/// wording rather than borrowing another trade's.
const Set<String> kTradesWithInspectionHints = {
  'Electrician',
  'Plumber',
  'AC Technician',
  'Carpenter',
  'Painter',
};

InspectionFieldHints _hintsFor(AppLocalizations l10n, String key) =>
    switch (key) {
      'Electrician' => InspectionFieldHints(
          issue: l10n.inspHintElectrical,
          repair: l10n.inspRepairHintElectrical,
          partName: l10n.inspPartHintElectrical,
        ),
      'Plumber' => InspectionFieldHints(
          issue: l10n.inspHintPlumbing,
          repair: l10n.inspRepairHintPlumbing,
          partName: l10n.inspPartHintPlumbing,
        ),
      'AC Technician' => InspectionFieldHints(
          issue: l10n.inspHintAc,
          repair: l10n.inspRepairHintAc,
          partName: l10n.inspPartHintAc,
        ),
      'Carpenter' => InspectionFieldHints(
          issue: l10n.inspHintCarpentry,
          repair: l10n.inspRepairHintCarpentry,
          partName: l10n.inspPartHintCarpentry,
        ),
      'Painter' => InspectionFieldHints(
          issue: l10n.inspHintPainting,
          repair: l10n.inspRepairHintPainting,
          partName: l10n.inspPartHintPainting,
        ),
      // Trade-neutral, so an unmapped or newly seeded backend category gets a
      // usable field instead of another trade's examples.
      _ => InspectionFieldHints(
          issue: l10n.inspHintFallback,
          repair: l10n.inspRepairHintFallback,
          partName: l10n.inspFormPartNameHint,
        ),
    };

/// Every example hint for [categoryName], falling back gracefully when it is
/// null or has no tailored entry.
InspectionFieldHints inspectionFieldHintsFor(
  AppLocalizations l10n,
  String? categoryName,
) =>
    _hintsFor(l10n, categoryName ?? '');

/// Convenience for the "what was the issue" field alone.
String inspectionIssueHintFor(AppLocalizations l10n, String? categoryName) =>
    inspectionFieldHintsFor(l10n, categoryName).issue;
