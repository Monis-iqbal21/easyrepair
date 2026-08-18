import { AuthService } from './auth.service';

/**
 * AuthService.logout — authoritative server-side session cleanup. Order
 * matters: the FCM token is detached BEFORE any forced-offline notification
 * can be created (WorkersService.handleWorkerLogout runs after), so that
 * notification is persisted but never pushed to the device that just logged
 * out (NotificationsService reads the token fresh from the DB at send time,
 * by which point it is already null).
 */
describe('AuthService.logout', () => {
  let repository: any;
  let workersService: any;
  let service: AuthService;

  beforeEach(() => {
    repository = {
      clearFcmToken: jest.fn().mockResolvedValue(undefined),
      deleteRefreshToken: jest.fn().mockResolvedValue(undefined),
      deleteAllRefreshTokens: jest.fn().mockResolvedValue(undefined),
    };
    workersService = { handleWorkerLogout: jest.fn().mockResolvedValue(undefined) };

    service = new AuthService(
      repository,
      {} as any,
      {} as any,
      {} as any,
      {} as any,
      {} as any,
      workersService,
    );
  });

  it('clears the FCM token before revoking the session', async () => {
    const order: string[] = [];
    repository.clearFcmToken.mockImplementation(async () => {
      order.push('clearFcmToken');
    });
    repository.deleteRefreshToken.mockImplementation(async () => {
      order.push('deleteRefreshToken');
    });

    await service.logout('user-1', 'refresh-token-1');

    expect(order).toEqual(['clearFcmToken', 'deleteRefreshToken']);
  });

  it('deletes only the presented refresh token when one is given', async () => {
    await service.logout('user-1', 'refresh-token-1');

    expect(repository.deleteRefreshToken).toHaveBeenCalledWith(
      'refresh-token-1',
    );
    expect(repository.deleteAllRefreshTokens).not.toHaveBeenCalled();
  });

  it('deletes every refresh token when none is presented', async () => {
    await service.logout('user-1');

    expect(repository.deleteAllRefreshTokens).toHaveBeenCalledWith('user-1');
    expect(repository.deleteRefreshToken).not.toHaveBeenCalled();
  });

  it('delegates Worker availability cleanup to WorkersService for every logout', async () => {
    await service.logout('user-1', 'refresh-token-1');

    // CLIENT accounts pass straight through as a no-op inside
    // handleWorkerLogout (no WorkerProfile) — AuthService itself never
    // branches on role, keeping logout a single authoritative path.
    expect(workersService.handleWorkerLogout).toHaveBeenCalledWith('user-1');
  });

  it('does not throw when Worker presence cleanup fails', async () => {
    workersService.handleWorkerLogout.mockRejectedValue(new Error('db down'));

    await expect(
      service.logout('user-1', 'refresh-token-1'),
    ).resolves.toBeUndefined();
  });

  it('does not throw when the refresh token was already gone', async () => {
    repository.deleteRefreshToken.mockRejectedValue(new Error('not found'));

    await expect(
      service.logout('user-1', 'refresh-token-1'),
    ).resolves.toBeUndefined();
  });
});
