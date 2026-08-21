import { NotFoundException } from '@nestjs/common';
import { AdminController } from './admin.controller';
import { AdminService } from './admin.service';
import { ROLES_KEY } from '../../common/decorators/roles.decorator';
import { Role } from '../../common/enums/role.enum';
import { sendPrivateFile } from '../../common/utils/private-file-response.util';

describe('Admin worker document security', () => {
  const publicBase = 'https://public.example.test';
  let repository: any;
  let storage: any;
  let service: AdminService;

  beforeEach(() => {
    repository = {
      findVerificationDocumentStorage: jest.fn(),
      findWorkerDocumentStorage: jest.fn(),
      findWorkerByIdFull: jest.fn(),
    };
    storage = {
      keyFromUrl: jest.fn((url: string) =>
        url.startsWith(`${publicBase}/`)
          ? url.slice(publicBase.length + 1)
          : null,
      ),
      getObject: jest.fn().mockResolvedValue({
        body: Buffer.from('private bytes'),
        contentType: 'image/jpeg',
      }),
    };
    service = new AdminService(repository, {} as any, {} as any, storage);
  });

  it('keeps every document route behind the controller ADMIN guard', () => {
    expect(Reflect.getMetadata(ROLES_KEY, AdminController)).toEqual([
      Role.ADMIN,
    ]);
  });

  it('does not serialize raw R2 URLs in the admin verification response', async () => {
    repository.findWorkerByIdFull.mockResolvedValue({
      id: 'worker-1',
      user: { id: 'user-1', phone: '+923001234567' },
      firstName: 'Ali',
      lastName: 'Khan',
      bio: null,
      avatarUrl: null,
      status: 'ACTIVE',
      verificationStatus: 'PENDING',
      skills: [],
      documents: [
        {
          id: 'document-1',
          type: 'CERTIFICATE',
          fileUrl: `${publicBase}/uploads/certificate.jpg`,
          fileName: 'certificate.jpg',
          mimeType: 'image/jpeg',
          verifiedAt: null,
          createdAt: new Date(),
        },
      ],
      createdAt: new Date(),
      updatedAt: new Date(),
      fullLegalName: 'Ali Khan',
      cnicNumber: '12345-1234567-1',
      residentialAddress: 'Lahore',
      cnicFrontUrl: `${publicBase}/uploads/front.jpg`,
      cnicBackUrl: `${publicBase}/uploads/back.jpg`,
      liveSelfieUrl: `${publicBase}/uploads/selfie.jpg`,
      faceMatchStatus: 'PENDING',
      trainingStatus: 'NOT_STARTED',
      onboardingStatus: 'SUBMITTED_FOR_REVIEW',
      legalNameConfirmedAt: null,
      generalAgreementAcceptedAt: null,
      tradeAgreementAcceptedAt: null,
      generalAgreementVersion: null,
      tradeAgreementVersion: null,
      submittedForReviewAt: null,
      changesRequiredReason: null,
      rejectionReason: null,
    });

    const result = await service.getWorkerById('worker-1');
    expect(JSON.stringify(result)).not.toContain(publicBase);
    expect(result.cnicFrontUrl).toBe(
      '/api/v1/admin/workers/worker-1/verification-documents/cnic-front/download',
    );
    expect(result.documents[0].fileUrl).toBe(
      '/api/v1/admin/workers/worker-1/documents/document-1/download',
    );
  });

  it('downloads a CNIC by storage key and never returns its public URL', async () => {
    repository.findVerificationDocumentStorage.mockResolvedValue({
      cnicFrontUrl: `${publicBase}/uploads/front.jpg`,
      cnicFrontStorageKey: 'uploads/front.jpg',
      cnicBackUrl: null,
      cnicBackStorageKey: null,
      liveSelfieUrl: null,
      liveSelfieStorageKey: null,
    });

    const result = await service.downloadVerificationDocument(
      'worker-1',
      'cnic-front',
    );
    expect(storage.getObject).toHaveBeenCalledWith('uploads/front.jpg');
    expect(result).toEqual({
      body: Buffer.from('private bytes'),
      contentType: 'image/jpeg',
      fileName: 'cnic-front.jpg',
    });
  });

  it('supports legacy rows by deriving the key without exposing the URL', async () => {
    repository.findVerificationDocumentStorage.mockResolvedValue({
      cnicFrontUrl: `${publicBase}/uploads/legacy-front.jpg`,
      cnicFrontStorageKey: null,
      cnicBackUrl: null,
      cnicBackStorageKey: null,
      liveSelfieUrl: null,
      liveSelfieStorageKey: null,
    });

    await service.downloadVerificationDocument('worker-1', 'cnic-front');
    expect(storage.keyFromUrl).toHaveBeenCalledWith(
      `${publicBase}/uploads/legacy-front.jpg`,
    );
    expect(storage.getObject).toHaveBeenCalledWith('uploads/legacy-front.jpg');
  });

  it('scopes general documents to the worker in the request path', async () => {
    repository.findWorkerDocumentStorage.mockResolvedValue(null);
    await expect(
      service.downloadWorkerDocument('worker-1', 'other-workers-document'),
    ).rejects.toBeInstanceOf(NotFoundException);
    expect(repository.findWorkerDocumentStorage).toHaveBeenCalledWith(
      'worker-1',
      'other-workers-document',
    );
    expect(storage.getObject).not.toHaveBeenCalled();
  });

  it('marks proxied bytes private, non-cacheable and non-sniffable', () => {
    const res = {
      headers: {} as Record<string, unknown>,
      setHeader(name: string, value: unknown) {
        this.headers[name] = value;
      },
      send: jest.fn(),
    };
    const body = Buffer.from('secret');
    sendPrivateFile(res as any, {
      body,
      contentType: 'image/jpeg',
      fileName: 'cnic front.jpg',
    });
    expect(res.headers['Cache-Control']).toBe('private, no-store, max-age=0');
    expect(res.headers['X-Content-Type-Options']).toBe('nosniff');
    expect(res.headers['Content-Disposition']).toBe(
      'inline; filename="cnic_front.jpg"',
    );
    expect(res.send).toHaveBeenCalledWith(body);
  });
});
