import '../../../../core/config/app_config.dart';
import '../../domain/entities/booking_entity.dart';
import '../../domain/entities/inspection_report_entity.dart';

class InspectionReportPartModel {
  final String id;
  final String name;
  final int quantity;
  final double? unitPrice;
  final String? warranty;
  final double? lineTotal;

  const InspectionReportPartModel({
    required this.id,
    required this.name,
    required this.quantity,
    this.unitPrice,
    this.warranty,
    this.lineTotal,
  });

  factory InspectionReportPartModel.fromJson(Map<String, dynamic> json) {
    return InspectionReportPartModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      // Absent (not zero) in the sanitized bidder view — a price was never sent.
      unitPrice: (json['unitPrice'] as num?)?.toDouble(),
      warranty: json['warranty'] as String?,
      lineTotal: (json['lineTotal'] as num?)?.toDouble(),
    );
  }

  InspectionReportPartEntity toEntity() => InspectionReportPartEntity(
        id: id,
        name: name,
        quantity: quantity,
        unitPrice: unitPrice,
        warranty: warranty,
        lineTotal: lineTotal,
      );
}

class InspectionReportPhotoModel {
  final String id;
  final String url;
  final DateTime createdAt;

  const InspectionReportPhotoModel({
    required this.id,
    required this.url,
    required this.createdAt,
  });

  factory InspectionReportPhotoModel.fromJson(Map<String, dynamic> json) {
    return InspectionReportPhotoModel(
      id: json['id'] as String? ?? '',
      url: json['url'] as String? ?? '',
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
    );
  }

  InspectionReportPhotoEntity toEntity() => InspectionReportPhotoEntity(
        id: id,
        url: resolveInspectionReportMediaUrl(url),
        createdAt: createdAt,
      );
}

String resolveInspectionReportMediaUrl(String raw) {
  if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
  final base = AppConfig.apiBaseUrl.replaceAll(RegExp(r'/api/v\d+/?$'), '');
  return raw.startsWith('/') ? '$base$raw' : '$base/$raw';
}

class InspectionReportModel {
  final String id;
  final String bookingId;
  /// Absent in the sanitized bidder/hired-different-worker view.
  final String? workerProfileId;
  final String? issueFound;
  final String? recommendedRepair;
  final double? labourCost;
  final bool partsNeeded;
  final double? partsTotal;
  final double? repairQuoteTotal;
  final double? inspectionFeeSnapshot;
  final String? notes;
  final String? voiceNoteUrl;
  final String? voiceNoteMimeType;
  final double? voiceNoteDurationSeconds;
  final String decisionStatus;
  final List<InspectionReportPartModel> parts;
  final List<InspectionReportPhotoModel> photos;
  final DateTime createdAt;
  final DateTime? acceptedAt;
  final DateTime? closedAt;

  const InspectionReportModel({
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
  });

  factory InspectionReportModel.fromJson(Map<String, dynamic> json) {
    final partsJson = json['parts'] as List<dynamic>? ?? [];
    final photosJson = json['photos'] as List<dynamic>? ?? [];
    final rawVoiceNoteUrl = json['voiceNoteUrl'] as String?;
    return InspectionReportModel(
      id: json['id'] as String? ?? '',
      bookingId: json['bookingId'] as String? ?? '',
      workerProfileId: json['workerProfileId'] as String?,
      issueFound: json['issueFound'] as String?,
      recommendedRepair: json['recommendedRepair'] as String?,
      // Absent (not zero) in the sanitized bidder/hired-different-worker view.
      labourCost: (json['labourCost'] as num?)?.toDouble(),
      partsNeeded: json['partsNeeded'] as bool? ?? false,
      partsTotal: (json['partsTotal'] as num?)?.toDouble(),
      repairQuoteTotal: (json['repairQuoteTotal'] as num?)?.toDouble(),
      inspectionFeeSnapshot:
          (json['inspectionFeeSnapshot'] as num?)?.toDouble(),
      notes: json['notes'] as String?,
      voiceNoteUrl: rawVoiceNoteUrl != null && rawVoiceNoteUrl.isNotEmpty
          ? resolveInspectionReportMediaUrl(rawVoiceNoteUrl)
          : null,
      voiceNoteMimeType: json['voiceNoteMimeType'] as String?,
      voiceNoteDurationSeconds:
          (json['voiceNoteDurationSeconds'] as num?)?.toDouble(),
      decisionStatus:
          json['decisionStatus'] as String? ?? 'PENDING_CLIENT_DECISION',
      parts: partsJson
          .map((e) => InspectionReportPartModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      photos: photosJson
          .map((e) => InspectionReportPhotoModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      acceptedAt: json['acceptedAt'] != null
          ? DateTime.tryParse(json['acceptedAt'] as String)
          : null,
      closedAt: json['closedAt'] != null
          ? DateTime.tryParse(json['closedAt'] as String)
          : null,
    );
  }

  InspectionReportEntity toEntity() => InspectionReportEntity(
        id: id,
        bookingId: bookingId,
        workerProfileId: workerProfileId,
        issueFound: issueFound,
        recommendedRepair: recommendedRepair,
        labourCost: labourCost,
        partsNeeded: partsNeeded,
        partsTotal: partsTotal,
        repairQuoteTotal: repairQuoteTotal,
        inspectionFeeSnapshot: inspectionFeeSnapshot,
        notes: notes,
        voiceNoteUrl: voiceNoteUrl,
        voiceNoteMimeType: voiceNoteMimeType,
        voiceNoteDurationSeconds: voiceNoteDurationSeconds,
        decisionStatus:
            InspectionDecisionStatusX.fromRaw(decisionStatus) ??
                InspectionDecisionStatus.pendingClientDecision,
        parts: parts.map((p) => p.toEntity()).toList(),
        photos: photos.map((p) => p.toEntity()).toList(),
        createdAt: createdAt,
        acceptedAt: acceptedAt,
        closedAt: closedAt,
      );
}
