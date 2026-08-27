import '../../domain/entities/complaint_entity.dart';

class ComplaintModel {
  const ComplaintModel(this.entity);

  final ComplaintEntity entity;

  factory ComplaintModel.fromJson(Map<String, dynamic> json) {
    final createdAt = DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0);
    final rawIssues = json['issueTypes'];
    final issueTypes = rawIssues is List
        ? rawIssues
            .map((value) => ComplaintIssueType.fromApi(value.toString()))
            .whereType<ComplaintIssueType>()
            .toList(growable: false)
        : const <ComplaintIssueType>[];

    return ComplaintModel(
      ComplaintEntity(
        id: json['id']?.toString() ?? '',
        bookingId: json['bookingId']?.toString(),
        reporterUserId: json['reporterUserId']?.toString(),
        reportedWorkerProfileId: json['reportedWorkerProfileId']?.toString(),
        issueTypes: issueTypes,
        otherText: _nullableText(json['otherText']),
        source: json['source']?.toString() ?? 'APP_CUSTOMER',
        status: ComplaintStatus.fromApi(json['status']?.toString()),
        humanRequested: json['humanRequested'] == true,
        humanRequestedAt: _date(json['humanRequestedAt']),
        resolvedAt: _date(json['resolvedAt']),
        createdAt: createdAt,
        updatedAt: _date(json['updatedAt']) ?? createdAt,
      ),
    );
  }

  ComplaintEntity toEntity() => entity;

  static String? _nullableText(dynamic value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  static DateTime? _date(dynamic value) =>
      DateTime.tryParse(value?.toString() ?? '');
}
