import { runWhenIdle } from "@/lib/open-loops/open-loop-defer";
import { recordFunctionInvocation } from "@/lib/open-loops/open-loop-performance";
import { runWriteAction } from "@/lib/runtime/render-safe";

export type DeferredJobType =
  | "refresh-open-loop-continuity"
  | "link-reflection-after-resurface"
  | "extract-thought-patterns";

export interface ExtractThoughtPatternsPayload {
  entryId: string;
  transcript: string;
}

export interface LinkReflectionAfterResurfacePayload {
  id: string;
  createdAt: string;
  transcript: string;
}

type DeferredJob =
  | { type: "refresh-open-loop-continuity" }
  | { type: "link-reflection-after-resurface"; payload: LinkReflectionAfterResurfacePayload }
  | { type: "extract-thought-patterns"; payload: ExtractThoughtPatternsPayload };

const queue: DeferredJob[] = [];
const pendingTypes = new Set<DeferredJobType>();
let flushScheduled = false;

async function executeJob(job: DeferredJob): Promise<void> {
  switch (job.type) {
    case "refresh-open-loop-continuity": {
      const { persistRefreshedOpenLoopContinuity } = await import(
        "@/lib/open-loops/open-loop-storage"
      );
      runWriteAction("deferred:refresh-open-loop-continuity", () => {
        persistRefreshedOpenLoopContinuity();
      });
      break;
    }
    case "link-reflection-after-resurface": {
      const { maybeLinkReflectionAfterOpenLoopResurface } = await import(
        "@/lib/open-loops/open-loop-storage"
      );
      runWriteAction("deferred:link-reflection-after-resurface", () => {
        maybeLinkReflectionAfterOpenLoopResurface(job.payload);
      });
      break;
    }
    case "extract-thought-patterns": {
      const { extractThoughtPatterns } = await import("@/lib/clarity/thought-patterns");
      const { persistThoughtPatternsForEntryInStore } = await import(
        "@/lib/clarity/clarity-storage"
      );
      runWriteAction("deferred:extract-thought-patterns", () => {
        const patterns = extractThoughtPatterns(job.payload.transcript);
        persistThoughtPatternsForEntryInStore(job.payload.entryId, patterns);
      });
      break;
    }
    default:
      break;
  }
}

function flushQueue(): void {
  flushScheduled = false;
  const batch = queue.splice(0, queue.length);
  for (const job of batch) {
    pendingTypes.delete(job.type);
  }
  for (const job of batch) {
    void executeJob(job);
  }
}

function scheduleFlush(): void {
  if (flushScheduled) return;
  flushScheduled = true;
  runWhenIdle(() => flushQueue());
}

function enqueue(job: DeferredJob): void {
  if (pendingTypes.has(job.type)) return;
  pendingTypes.add(job.type);
  queue.push(job);
  recordFunctionInvocation(`deferred:${job.type}`);
  scheduleFlush();
}

export function enqueueRefreshOpenLoopContinuity(): void {
  enqueue({ type: "refresh-open-loop-continuity" });
}

/** @deprecated Use enqueueRefreshOpenLoopContinuity */
export function scheduleOpenLoopContinuityRefresh(): void {
  enqueueRefreshOpenLoopContinuity();
}

export function enqueueLinkReflectionAfterResurface(
  payload: LinkReflectionAfterResurfacePayload,
): void {
  enqueue({ type: "link-reflection-after-resurface", payload });
}

export function enqueueExtractThoughtPatterns(
  payload: ExtractThoughtPatternsPayload,
): void {
  enqueue({ type: "extract-thought-patterns", payload });
}

export function resetDeferredJobQueue(): void {
  queue.length = 0;
  pendingTypes.clear();
  flushScheduled = false;
}

export function deferredJobQueueDepth(): number {
  return queue.length;
}
