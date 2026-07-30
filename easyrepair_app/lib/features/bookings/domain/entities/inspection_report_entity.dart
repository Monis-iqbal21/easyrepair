import 'booking_entity.dart';

class InspectionReportPartEntity {
  final String id;
  final String name;
  final int quantity;
  /// Null in the sanitized view shown to a not-yet-hired bidder or a hired
  /// different worker — they may see what parts are needed, never the price.
  final double? unitPrice;
  final String? warranty;
  final double? lineTotal;

  const InspectionReportPartEntity({
    required this.id,
    required this.name,
    required this.quantity,
    this.unitPrice,
    this.warranty,
    this.lineTotal,
  });
}

class InspectionReportPhotoEntity {
  final String id;
  final String url;
  final DateTime createdAt;

  const InspectionReportPhotoEntity({
    required this.id,
    required this.url,
    required this.createdAt,
  });
}

class InspectionReportEntity {
  final String id;
  final String bookingId;
  /// Null in the sanitized bidder/hired-different-worker view.
  final String? workerProfileId;
  final String? issueFound;
  final String? recommendedRepair;
  /// Null in the sanitized view — never shown before hiring the inspector.
  final double? labourCost;
  final bool partsNeeded;
  /// Null in the sanitized view.
  final double? partsTotal;
  /// Null in the sanitized view.
  final double? repairQuoteTotal;
  final double? inspectionFeeSnapshot;
  final String? notes;
  final String? voiceNoteUrl;
  final String? voiceNoteMimeType;
  final double? voiceNoteDurationSeconds;
  final InspectionDecisionStatus decisionStatus;
  final List<InspectionReportPartEntity> parts;
  final List<InspectionReportPhotoEntity> photos;
  final DateTime createdAt;
  final DateTime? acceptedAt;
  final DateTime? closedAt;

  /// Set once "Find Other Ustaad" has spawned the linked repair booking —
  /// where the client's bidding list for this repair now lives. Null before
  /// the decision, in the sanitized view, and for pre-fix historical records.
  final String? linkedRepairBookingId;

  /// True when this is the sanitized bidder/hired-different-worker view —
  /// no pricing fields present. Widgets should hide the whole pricing
  /// summary card rather than show misleading zeros.
  bool get isSanitized => labourCost == null;

  const InspectionReportEntity({
    required this.id,
    required this.bookingId,
    this.workerProfileId,
    this.issueFound,
    this.recommendedRepair,
    this.labourCost,
    required this.partsNeeded,
    this.partsTotal,
    this.repairQuoteTotal,
    this.inspectionFeeSnapshot,
    this.notes,
    this.voiceNoteUrl,
    this.voiceNoteMimeType,
    this.voiceNoteDurationSeconds,
    required this.decisionStatus,
    this.parts = const [],
    this.photos = const [],
    required this.createdAt,
    this.acceptedAt,
    this.closedAt,
    this.linkedRepairBookingId,
  });
}

/// One part line being built up in the worker's report form before submit.
class InspectionReportPartDraft {
  final String name;
  final int quantity;
  final double unitPrice;
  final String? warranty;

  const InspectionReportPartDraft({
    this.name = '',
    this.quantity = 1,
    this.unitPrice = 0,
    this.warranty,
  });

  double get lineTotal => quantity * unitPrice;

  InspectionReportPartDraft copyWith({
    String? name,
    int? quantity,
    double? unitPrice,
    String? warranty,
  }) {
    return InspectionReportPartDraft(
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      warranty: warranty ?? this.warranty,
    );
  }
}
