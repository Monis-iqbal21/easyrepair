import { JobCompletionNotifierService } from './job-completion-notifier.service';

describe('JobCompletionNotifierService', () => {
  let matchingRepository: any;
  let notificationsService: any;
  let service: JobCompletionNotifierService;

  beforeEach(() => {
    matchingRepository = {
      findBookingForCompletionNotice: jest.fn().mockResolvedValue({
        id: 'booking-1',
        status: 'COMPLETED',
        clientProfile: { userId: 'client-user-1' },
      }),
    };
    notificationsService = {
      notify: jest.fn().mockResolvedValue(undefined),
      wasAlreadyNotified: jest.fn().mockResolvedValue(false),
    };
    service = new JobCompletionNotifierService(
      matchingRepository,
      notificationsService,
    );
  });

  // ── One event key, whatever the variant ───────────────────────────────────
  it('always uses the booking.completed event key', async () => {
    await service.notifyClientJobCompleted('booking-1', 'NORMAL');
    await service.notifyClientJobCompleted('booking-2', 'INSPECTION_BEFORE_SWITCH');

    for (const call of notificationsService.notify.mock.calls) {
      expect(call[0].eventKey).toBe('booking.completed');
    }
  });

  // ── Roman Urdu copy per variant ───────────────────────────────────────────
  it('uses the normal-completion Roman Urdu copy by default', async () => {
    await service.notifyClientJobCompleted('booking-1');

    const call = notificationsService.notify.mock.calls[0][0];
    expect(call.title).toBe('Kaam Mukammal Ho Gaya');
    expect(call.body).toBe('Apne Ustaad ko review dein.');
    expect(call.userId).toBe('client-user-1');
    expect(call.route).toBe('/client/booking/booking-1');
  });

  it('uses the inspection-before-switch Roman Urdu copy', async () => {
    await service.notifyClientJobCompleted(
      'booking-1',
      'INSPECTION_BEFORE_SWITCH',
    );

    const call = notificationsService.notify.mock.calls[0][0];
    expect(call.title).toBe('Inspection Mukammal Ho Gayi');
    expect(call.body).toBe(
      'Inspection Ustaad ko review dein, phir doosre Ustaads ki offers dekhein.',
    );
  });

  // ── Exactly one notification per completed work unit ──────────────────────
  //
  // Completion is reachable from four overlapping call sites. Dedup lives
  // inside this helper so they can only ever produce one notification.
  it('sends exactly one booking.completed even when several call sites fire', async () => {
    // Simulate the ledger: the first send lands, subsequent checks see it.
    let sent = false;
    notificationsService.wasAlreadyNotified.mockImplementation(() =>
      Promise.resolve(sent),
    );
    notificationsService.notify.mockImplementation(() => {
      sent = true;
      return Promise.resolve(undefined);
    });

    // BookingsService.completeJob, WorkersService.completeJob and
    // completeAfterInspectionClose all targeting the same work unit.
    await service.notifyClientJobCompleted('booking-1', 'NORMAL');
    await service.notifyClientJobCompleted('booking-1', 'NORMAL');
    await service.notifyClientJobCompleted('booking-1', 'NORMAL');

    expect(notificationsService.notify).toHaveBeenCalledTimes(1);
  });

  it('scopes the dedup check to this exact booking and the completion key', async () => {
    await service.notifyClientJobCompleted('booking-1');

    expect(notificationsService.wasAlreadyNotified).toHaveBeenCalledWith(
      'client-user-1',
      'booking-1',
      'booking.completed',
    );
  });

  // ── The reviewed work unit is the ORIGINAL inspection, never the child ────
  it('notifies for whichever booking id the caller names — the original inspection for Find Other Ustaad', async () => {
    matchingRepository.findBookingForCompletionNotice.mockResolvedValue({
      id: 'inspection-1',
      status: 'COMPLETED',
      clientProfile: { userId: 'client-user-1' },
    });

    await service.notifyClientJobCompleted(
      'inspection-1',
      'INSPECTION_BEFORE_SWITCH',
    );

    expect(
      matchingRepository.findBookingForCompletionNotice,
    ).toHaveBeenCalledWith('inspection-1');
    const call = notificationsService.notify.mock.calls[0][0];
    expect(call.bookingId).toBe('inspection-1');
    expect(call.entityId).toBe('inspection-1');
    expect(call.route).toBe('/client/booking/inspection-1');
  });

  // ── Safety ────────────────────────────────────────────────────────────────
  it('does nothing when the booking or its client cannot be resolved', async () => {
    matchingRepository.findBookingForCompletionNotice.mockResolvedValue(null);
    await service.notifyClientJobCompleted('missing');
    expect(notificationsService.notify).not.toHaveBeenCalled();
  });

  it('never throws, so callers can safely fire-and-forget', async () => {
    matchingRepository.findBookingForCompletionNotice.mockRejectedValue(
      new Error('db down'),
    );
    await expect(
      service.notifyClientJobCompleted('booking-1'),
    ).resolves.toBeUndefined();
  });
});
