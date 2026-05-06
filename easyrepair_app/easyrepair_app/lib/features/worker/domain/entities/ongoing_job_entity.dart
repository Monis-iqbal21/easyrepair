class OngoingJobEntity {
  final String id;
  final String? title;
  final String categoryName;
  final String clientArea;
  final String addressLine;
  final String status;

  const OngoingJobEntity({
    required this.id,
    this.title,
    required this.categoryName,
    required this.clientArea,
    required this.addressLine,
    required this.status,
  });

  String get displayStatus {
    switch (status.toUpperCase()) {
      case 'ACCEPTED':
        return 'Assigned';
      case 'EN_ROUTE':
        return 'On the Way';
      case 'IN_PROGRESS':
        return 'In Progress';
      default:
        return status;
    }
  }
}
