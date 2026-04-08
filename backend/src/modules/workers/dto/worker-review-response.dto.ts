export class WorkerReviewResponseDto {
  id: string;
  rating: number;
  comment: string | null;
  serviceCategory: string;
  clientName: string | null;
  createdAt: string;
}

export class WorkerReviewSummaryDto {
  totalReviews: number;
  averageRating: number;
}
