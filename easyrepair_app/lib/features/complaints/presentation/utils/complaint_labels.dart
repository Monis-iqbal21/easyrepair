import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/complaint_entity.dart';

String complaintIssueLabel(
  AppLocalizations l10n,
  ComplaintIssueType issue,
) =>
    switch (issue) {
      ComplaintIssueType.workQuality => l10n.reportIssueWorkQuality,
      ComplaintIssueType.pricePayment => l10n.reportIssuePricePayment,
      ComplaintIssueType.ustaadBehaviour => l10n.reportIssueUstaadBehaviour,
      ComplaintIssueType.damage => l10n.reportIssueDamage,
      ComplaintIssueType.partMaterial => l10n.reportIssuePartMaterial,
      ComplaintIssueType.warrantyRework => l10n.reportIssueWarrantyRework,
      ComplaintIssueType.other => l10n.reportIssueOther,
    };

String complaintStatusLabel(
  AppLocalizations l10n,
  ComplaintStatus status,
) =>
    switch (status) {
      ComplaintStatus.open => l10n.reportStatusPending,
      ComplaintStatus.inProgress || ComplaintStatus.waitingOnCustomer =>
        l10n.reportStatusInReview,
      ComplaintStatus.resolved || ComplaintStatus.closed =>
        l10n.reportStatusResolved,
    };
