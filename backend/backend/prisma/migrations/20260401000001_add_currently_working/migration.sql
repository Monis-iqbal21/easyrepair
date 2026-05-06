-- AlterTable: add currentlyWorking boolean to worker_profiles
ALTER TABLE "worker_profiles" ADD COLUMN "currentlyWorking" BOOLEAN NOT NULL DEFAULT false;
