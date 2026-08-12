import { IsEnum } from 'class-validator';
import { WorkerStatus } from '@prisma/client';

/**
 * PATCH /admin/workers/:id/status — the ONE mechanism that flips
 * WorkerProfile.status. This is the same field the worker app's central
 * routing gate already reads fresh on every login/me/refresh call — there is
 * no separate suspension flag or enforcement path to keep in sync.
 */
export class UpdateWorkerStatusDto {
  @IsEnum(WorkerStatus)
  status: WorkerStatus;
}
