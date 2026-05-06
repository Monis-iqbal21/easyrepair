class WorkerSkillEntity {
  final String id;
  final String categoryId;
  final String categoryName;
  final String? categoryIconUrl;
  final int yearsExperience;

  const WorkerSkillEntity({
    required this.id,
    required this.categoryId,
    required this.categoryName,
    this.categoryIconUrl,
    required this.yearsExperience,
  });
}
