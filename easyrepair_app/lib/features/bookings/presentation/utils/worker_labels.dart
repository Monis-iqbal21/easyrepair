import '../../../../l10n/app_localizations.dart';

/// Display labels for an Ustaad's rating and distance.
///
/// These used to be getters on the domain entities, but the wording depends on
/// the selected language, so they belong here — the entities now expose only
/// the raw numbers.

/// "4.6/5 (12 jobs)", or "New worker" when nobody has hired them yet.
String workerRatingLabel(
  AppLocalizations l10n,
  double rating,
  int completedJobs,
) {
  if (completedJobs == 0) return l10n.workerRatingNew;
  final score =
      rating > 0 ? '${rating.toStringAsFixed(1)}/5' : l10n.workerRatingNone;
  return l10n.workerRatingWithJobs(score, completedJobs);
}

/// Distance from the client, rounded the way each range reads best.
String workerDistanceLabel(AppLocalizations l10n, double? distanceKm) {
  if (distanceKm == null) return '';
  if (distanceKm < 1) return l10n.distanceUnderOneKm;
  return l10n.distanceKmAway(distanceKm.toStringAsFixed(1));
}
