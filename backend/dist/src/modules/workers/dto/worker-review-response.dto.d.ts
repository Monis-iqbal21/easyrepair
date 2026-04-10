export declare class WorkerReviewResponseDto {
    id: string;
    bookingId: string;
    rating: number;
    comment: string | null;
    serviceCategory: string;
    clientName: string | null;
    createdAt: string;
}
export declare class WorkerReviewSummaryDto {
    totalReviews: number;
    averageRating: number;
}
