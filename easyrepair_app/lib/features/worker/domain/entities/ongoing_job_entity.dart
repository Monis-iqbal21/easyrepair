class OngoingJobEntity {
  final String id;
  final String? title;
  final String categoryName;
  final String clientArea;
  final String addressLine;
  final String status;
  final String lane;

  const OngoingJobEntity({
    required this.id,
    this.title,
    required this.categoryName,
    required this.clientArea,
    required this.addressLine,
    required this.status,
    this.lane = 'STANDARD',
  });

  // The visible label is built by ongoingJobStatusLabel() in
  // presentation/utils/worker_labels.dart; `status` stays the backend token.
}
