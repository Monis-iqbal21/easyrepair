/// One of the client's own previously completed inspections, offered in the
/// "attach a previous inspection report" selector while posting a BIDDING
/// job.
///
/// Deliberately lightweight — enough to recognise the inspection, never a
/// copy of the report itself. The full report is always read through the
/// existing report viewer against the booking that references it, so the
/// report has exactly one source of truth.
class AttachableInspectionEntity {
  /// The historical INSPECTION booking's id — this is what gets attached.
  final String bookingId;
  final String categoryId;
  final String categoryName;
  final DateTime inspectionDate;
  final String? issueFound;
  final String? recommendedRepair;

  const AttachableInspectionEntity({
    required this.bookingId,
    required this.categoryId,
    required this.categoryName,
    required this.inspectionDate,
    this.issueFound,
    this.recommendedRepair,
  });

  factory AttachableInspectionEntity.fromJson(Map<String, dynamic> json) {
    return AttachableInspectionEntity(
      bookingId: json['bookingId'] as String,
      categoryId: json['categoryId'] as String? ?? '',
      categoryName: json['categoryName'] as String? ?? '',
      inspectionDate:
          DateTime.tryParse(json['inspectionDate'] as String? ?? '') ??
              DateTime.now(),
      issueFound: json['issueFound'] as String?,
      recommendedRepair: json['recommendedRepair'] as String?,
    );
  }

  /// The one-line diagnosis shown on the selector row and the selected card,
  /// when the report captured one in text (a voice-note-only report has none).
  String? get summary {
    final issue = issueFound?.trim();
    if (issue != null && issue.isNotEmpty) return issue;
    final repair = recommendedRepair?.trim();
    if (repair != null && repair.isNotEmpty) return repair;
    return null;
  }
}
