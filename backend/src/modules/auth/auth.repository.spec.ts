import { AuthRepository } from './auth.repository';

/**
 * Account deletion (`deleteAccount` → `softDeleteUser`) must never touch a
 * Client's or Worker's legal agreement-acceptance records or their stored
 * PDFs. This is what actually makes the SetNull relation fix meaningful in
 * practice: even the one place a "delete account" request lands never issues
 * a delete/update against `agreementAcceptance`, and never calls into
 * storage at all — so an accepted agreement's row, its snapshot fields and
 * its sealed PDF object all survive account deletion untouched.
 */
describe('AuthRepository.softDeleteUser — legal-preservation', () => {
  it('is a SOFT delete: only updates the user row and clears sessions', async () => {
    const calls: string[] = [];
    const tx = {
      user: {
        update: jest.fn(async (args: unknown) => {
          calls.push('user.update');
          return args;
        }),
      },
      refreshToken: {
        deleteMany: jest.fn(async () => {
          calls.push('refreshToken.deleteMany');
          return { count: 0 };
        }),
      },
      // Present so a future accidental call would be caught, not silently
      // succeed against an undefined property.
      agreementAcceptance: {
        delete: jest.fn(),
        deleteMany: jest.fn(),
        update: jest.fn(),
        updateMany: jest.fn(),
      },
    };
    const prisma = {
      $transaction: jest.fn(async (fn: (arg: typeof tx) => Promise<void>) =>
        fn(tx),
      ),
    };

    const repository = new AuthRepository(prisma as never);
    await repository.softDeleteUser('user-1');

    expect(calls).toEqual(['user.update', 'refreshToken.deleteMany']);
  });

  it('never deletes, updates or otherwise touches agreementAcceptance rows', async () => {
    const tx = {
      user: { update: jest.fn(async () => ({})) },
      refreshToken: { deleteMany: jest.fn(async () => ({ count: 0 })) },
      agreementAcceptance: {
        delete: jest.fn(),
        deleteMany: jest.fn(),
        update: jest.fn(),
        updateMany: jest.fn(),
      },
    };
    const prisma = {
      $transaction: jest.fn(async (fn: (arg: typeof tx) => Promise<void>) =>
        fn(tx),
      ),
    };

    const repository = new AuthRepository(prisma as never);
    await repository.softDeleteUser('user-1');

    expect(tx.agreementAcceptance.delete).not.toHaveBeenCalled();
    expect(tx.agreementAcceptance.deleteMany).not.toHaveBeenCalled();
    expect(tx.agreementAcceptance.update).not.toHaveBeenCalled();
    expect(tx.agreementAcceptance.updateMany).not.toHaveBeenCalled();
  });

  it('sets deletedAt / isActive: false rather than issuing a hard delete', async () => {
    let updateArgs: {
      where: { id: string };
      data: Record<string, unknown>;
    } | null = null;
    const tx = {
      user: {
        update: jest.fn(async (args: typeof updateArgs) => {
          updateArgs = args;
          return {};
        }),
      },
      refreshToken: { deleteMany: jest.fn(async () => ({ count: 0 })) },
    };
    const prisma = {
      $transaction: jest.fn(async (fn: (arg: typeof tx) => Promise<void>) =>
        fn(tx),
      ),
    };

    const repository = new AuthRepository(prisma as never);
    await repository.softDeleteUser('user-42');

    expect(updateArgs).not.toBeNull();
    expect(updateArgs!.where).toEqual({ id: 'user-42' });
    expect(updateArgs!.data).toMatchObject({ isActive: false });
    expect(updateArgs!.data.deletedAt).toBeInstanceOf(Date);
  });
});

/**
 * A physical FCM token must never remain simultaneously associated with two
 * User rows — e.g. a Worker logging out and a Client logging in on the same
 * physical device. Single-`fcmToken`-column architecture (no per-device
 * table), so exclusivity is enforced by atomically detaching the token from
 * every other row before assigning it to the caller.
 */
describe('AuthRepository.saveFcmToken — exclusive token ownership', () => {
  it('detaches the token from any other user, then assigns it to this user, in one transaction', async () => {
    const calls: Array<{ op: string; args: unknown }> = [];
    const prisma = {
      user: {
        updateMany: jest.fn((args: unknown) => {
          calls.push({ op: 'updateMany', args });
          return Promise.resolve({ count: 1 });
        }),
        update: jest.fn((args: unknown) => {
          calls.push({ op: 'update', args });
          return Promise.resolve({});
        }),
      },
      $transaction: jest.fn((ops: Promise<unknown>[]) => Promise.all(ops)),
    };

    const repository = new AuthRepository(prisma as never);
    await repository.saveFcmToken('user-2', 'token-abc', 'en');

    expect(prisma.user.updateMany).toHaveBeenCalledWith({
      where: { fcmToken: 'token-abc', id: { not: 'user-2' } },
      data: { fcmToken: null },
    });
    expect(prisma.user.update).toHaveBeenCalledWith({
      where: { id: 'user-2' },
      data: { fcmToken: 'token-abc', notificationLocale: 'en' },
    });
    // Detach is built (and handed to $transaction) before assign, so a
    // reader observing the transaction's effects never sees the token on
    // two rows at once.
    expect(calls.map((c) => c.op)).toEqual(['updateMany', 'update']);
    expect(prisma.$transaction).toHaveBeenCalledTimes(1);
  });

  it('keeps the existing locale when an older app omits it', async () => {
    const prisma = {
      user: {
        updateMany: jest.fn().mockResolvedValue({ count: 0 }),
        update: jest.fn().mockResolvedValue({}),
      },
      $transaction: jest.fn((ops: Promise<unknown>[]) => Promise.all(ops)),
    };
    const repository = new AuthRepository(prisma as never);

    await repository.saveFcmToken('user-2', 'legacy-token');

    expect(prisma.user.update).toHaveBeenCalledWith({
      where: { id: 'user-2' },
      data: { fcmToken: 'legacy-token' },
    });
  });
});

describe('AuthRepository.clearFcmToken', () => {
  it('nulls out fcmToken for exactly the given user', async () => {
    const prisma = { user: { update: jest.fn().mockResolvedValue({}) } };
    const repository = new AuthRepository(prisma as never);

    await repository.clearFcmToken('user-1');

    expect(prisma.user.update).toHaveBeenCalledWith({
      where: { id: 'user-1' },
      data: { fcmToken: null },
    });
  });
});
