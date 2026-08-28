/**
 * The public profile of one Ustaad, as shown in the Standard/Inspection
 * worker-selection modal (GET /bookings/:id/nearby-workers/:workerProfileId/profile).
 *
 * PRIVACY CONTRACT — this DTO is the whole surface a Client can see of a
 * Worker they have not hired. It deliberately carries no CNIC number, no
 * CNIC/selfie image url or storage key, no residential address, no date of
 * birth, no father's name, no emergency contact, no onboarding/verification
 * enum, no rejection or admin-review metadata, and no booking data belonging
 * to the reviewers. Anything added here becomes visible to every client who
 * can see this worker in a selection list — add nothing without that in mind.
 */

export class NearbyWorkerSkillDto {
  /** Service category name, e.g. "AC Repair". */
  name: string;
  /** Years recorded on this worker's WorkerSkill row for that category. */
  yearsExperience: number;
}

export class NearbyWorkerReviewDto {
  id: string;
  rating: number;
  comment: string | null;
  /** Reviewer's display name — the same first+last the worker's own reviews
   *  screen shows. Null when the client profile is gone. */
  reviewerName: string | null;
  serviceCategory: string;
  createdAt: string;
}

export class NearbyWorkerProfileDto {
  workerProfileId: string;
  firstName: string;
  lastName: string;
  avatarUrl: string | null;
  /** The Ustaad's normal contact number from their User record. */
  phone: string | null;
  averageRating: number;
  totalReviews: number;
  completedJobs: number;
  /**
   * True only when an admin has manually matched this Ustaad's CNIC photos
   * against their live selfie (FaceMatchStatus.MATCHED). Never inferred from
   * document presence, profile completeness, worker status or onboarding
   * approval.
   */
  cnicVerified: boolean;
  /**
   * Years of experience on the skill matching THIS booking's category. Null
   * when the worker has no such skill row. Never a sum across skills.
   */
  relevantExperienceYears: number | null;
  skills: NearbyWorkerSkillDto[];
  /** The latest 5 reviews at most, newest first. Empty when there are none. */
  reviews: NearbyWorkerReviewDto[];
}
