export class BidWorkerDto {
  id: string;
  firstName: string;
  lastName: string;
  avatarUrl: string | null;
  rating: number;
  completedJobs: number;
  distanceKm: number | null;
  currentLat: number | null;
  currentLng: number | null;
  locationUpdatedAt: Date | null;
}

export class BidResponseDto {
  id: string;
  bookingId: string;
  amount: number;
  message: string | null;
  status: string;
  editCount: number;
  createdAt: Date;
  updatedAt: Date;
  worker: BidWorkerDto;
}
