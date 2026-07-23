/** GET /admin/stats — dashboard counters for the admin panel. */
export class AdminStatsResponseDto {
  pendingUstaads: number;
  approvedUstaads: number;
  rejectedUstaads: number;
  changesRequiredUstaads: number;
  totalWorkers: number;
  totalUsers: number;
}
