-- CreateEnum
CREATE TYPE "WorkerOnboardingStatus" AS ENUM ('DRAFT', 'SUBMITTED_FOR_REVIEW', 'CHANGES_REQUIRED', 'REJECTED', 'APPROVED');

-- CreateEnum
CREATE TYPE "FaceMatchStatus" AS ENUM ('PENDING', 'MATCHED', 'NOT_MATCHED', 'NEEDS_REVIEW');

-- CreateEnum
CREATE TYPE "TrainingStatus" AS ENUM ('NOT_STARTED', 'INVITED', 'COMPLETED', 'NEEDS_RETRAINING');

-- AlterTable
ALTER TABLE "worker_profiles" ADD COLUMN     "changesRequiredReason" TEXT,
ADD COLUMN     "cnicBackStorageKey" TEXT,
ADD COLUMN     "cnicBackUrl" TEXT,
ADD COLUMN     "cnicFrontStorageKey" TEXT,
ADD COLUMN     "cnicFrontUrl" TEXT,
ADD COLUMN     "faceMatchStatus" "FaceMatchStatus" NOT NULL DEFAULT 'PENDING',
ADD COLUMN     "fullLegalName" TEXT,
ADD COLUMN     "generalAgreementAcceptedAt" TIMESTAMPTZ(3),
ADD COLUMN     "generalAgreementVersion" TEXT,
ADD COLUMN     "legalNameConfirmedAt" TIMESTAMPTZ(3),
ADD COLUMN     "liveSelfieStorageKey" TEXT,
ADD COLUMN     "liveSelfieUrl" TEXT,
ADD COLUMN     "onboardingStatus" "WorkerOnboardingStatus" NOT NULL DEFAULT 'DRAFT',
ADD COLUMN     "rejectionReason" TEXT,
ADD COLUMN     "residentialAddress" TEXT,
ADD COLUMN     "submittedForReviewAt" TIMESTAMPTZ(3),
ADD COLUMN     "tradeAgreementAcceptedAt" TIMESTAMPTZ(3),
ADD COLUMN     "tradeAgreementVersion" TEXT,
ADD COLUMN     "trainingStatus" "TrainingStatus" NOT NULL DEFAULT 'NOT_STARTED';
