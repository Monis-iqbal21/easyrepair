/**
 * Thrown inside a repository-layer Prisma `$transaction` when a
 * conditional `updateMany` guard finds the worker is no longer assignable
 * (already currentlyWorking, no longer active/verified/online/profile-
 * complete) — i.e. the assignment lost a race with another concurrent
 * assignment. Throwing this inside the transaction callback rolls back
 * every prior write in that same transaction.
 *
 * Plain Error, not a Nest HTTP exception — repositories in this codebase
 * never throw Nest exceptions directly; the owning service catches this
 * and translates it into a ConflictException (409).
 */
export class WorkerUnavailableError extends Error {
  constructor() {
    super('Worker is no longer available for assignment.');
    this.name = 'WorkerUnavailableError';
  }
}
