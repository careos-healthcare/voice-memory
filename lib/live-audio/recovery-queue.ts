import { EventEmitter } from "events";
import fs from "fs";
import path from "path";
import { processVaultRecoveryUpload } from "./vault-recovery-process";

export interface RecoveryJob {
  jobId: string;
  sessionId: string;
  filePath: string;
  secretKeyHex: string;
  status: "queued" | "processing" | "completed" | "failed";
  result?: {
    transcript: string;
    reflection: string;
    durationSeconds: number;
    frameCount: number;
  };
  error?: string;
  createdAt: number;
  updatedAt: number;
}

const STATE_FILE = path.join("/tmp", "vault_recovery_jobs.json");
const JOB_TIMEOUT_MS = 5 * 60 * 1000;

class VaultRecoveryQueue extends EventEmitter {
  private jobs = new Map<string, RecoveryJob>();
  private activeCount = 0;
  private maxConcurrency = 3;

  constructor() {
    super();
    this.loadState();
  }

  private async loadState() {
    try {
      if (fs.existsSync(STATE_FILE)) {
        const raw = await fs.promises.readFile(STATE_FILE, "utf-8");
        const list: RecoveryJob[] = JSON.parse(raw);
        for (const job of list) {
          if (job.status === "processing") {
            job.status = "queued";
          }
          this.jobs.set(job.jobId, job);
        }
        process.nextTick(() => this.processNext());
      }
    } catch {}
  }

  private async persistState() {
    try {
      const list = Array.from(this.jobs.values());
      await fs.promises.writeFile(STATE_FILE, JSON.stringify(list, null, 2));
    } catch {}
  }

  public enqueue(payload: { jobId: string; sessionId: string; filePath: string; secretKey: Buffer }): RecoveryJob {
    const now = Date.now();
    const job: RecoveryJob = {
      jobId: payload.jobId,
      sessionId: payload.sessionId,
      filePath: payload.filePath,
      secretKeyHex: payload.secretKey.toString("hex"),
      status: "queued",
      createdAt: now,
      updatedAt: now,
    };

    this.jobs.set(job.jobId, job);
    this.persistState();
    process.nextTick(() => this.processNext());
    return job;
  }

  public getJob(jobId: string): RecoveryJob | undefined {
    return this.jobs.get(jobId);
  }

  private async processNext() {
    if (this.activeCount >= this.maxConcurrency) return;

    const nextJob = Array.from(this.jobs.values()).find((j) => j.status === "queued");
    if (!nextJob) return;

    this.activeCount++;
    nextJob.status = "processing";
    nextJob.updatedAt = Date.now();
    await this.persistState();

    let timeoutTimer: NodeJS.Timeout | null = null;

    try {
      const vaultBuffer = await fs.promises.readFile(nextJob.filePath);
      const secretKey = Buffer.from(nextJob.secretKeyHex, "hex");

      const processingPromise = processVaultRecoveryUpload({
        subject: `recovery:${nextJob.sessionId}`,
        sessionId: nextJob.sessionId,
        idempotencyKey: nextJob.jobId,
        vaultBytes: vaultBuffer,
        inlineRecoverySecret: secretKey,
      });

      const timeoutPromise = new Promise<never>((_, reject) => {
        timeoutTimer = setTimeout(() => {
          reject(new Error("Recovery job exceeded max timeout of " + (JOB_TIMEOUT_MS / 1000) + "s"));
        }, JOB_TIMEOUT_MS);
      });

      const processed = await Promise.race([processingPromise, timeoutPromise]);

      nextJob.status = "completed";
      nextJob.result = {
        transcript: processed.transcript,
        reflection: JSON.stringify(processed.reflection),
        durationSeconds: processed.durationSeconds,
        frameCount: processed.frameCount,
      };

      await fs.promises.unlink(nextJob.filePath).catch(() => {});
    } catch (err) {
      nextJob.status = "failed";
      nextJob.error = err instanceof Error ? err.message : String(err);
    } finally {
      if (timeoutTimer) clearTimeout(timeoutTimer);
      nextJob.updatedAt = Date.now();
      this.activeCount--;
      await this.persistState();
      this.processNext();
    }
  }
}

export const recoveryQueue = new VaultRecoveryQueue();
