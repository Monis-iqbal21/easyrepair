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
      $transaction: jest.fn(
        async (fn: (arg: typeof tx) => Promise<void>) => fn(tx),
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
      $transaction: jest.fn(
        async (fn: (arg: typeof tx) => Promise<void>) => fn(tx),
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
    let updateArgs: { where: { id: string }; data: Record<string, unknown> } | null =
      null;
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
      $transaction: jest.fn(
        async (fn: (arg: typeof tx) => Promise<void>) => fn(tx),
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
