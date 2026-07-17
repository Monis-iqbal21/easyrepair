import 'booking_entity.dart';

class InspectionReportPartEntity {
  final String id;
  final String name;
  final int quantity;
  final double unitPrice;
  final String? warranty;
  final double lineTotal;

  const InspectionReportPartEntity({
    required this.id,
    required this.name,
    required this.quantity,
    required this.unitPrice,
    this.warranty,
    required this.lineTotal,
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
  final String workerProfileId;
  final String? issueFound;
  final String? recommendedRepair;
  final double labourCost;
  final bool partsNeeded;
  final double partsTotal;
  final double repairQuoteTotal;
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

  const InspectionReportEntity({
    required this.id,
    required this.bookingId,
    required this.workerProfileId,
    this.issueFound,
    this.recommendedRepair,
    required this.labourCost,
    required this.partsNeeded,
    required this.partsTotal,
    required this.repairQuoteTotal,
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
