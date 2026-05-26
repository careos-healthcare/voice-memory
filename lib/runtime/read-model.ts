import {
  auditOpenLoopActivation,
  resolveOpenLoopActivation,
  type OpenLoopActivationAudit,
  type OpenLoopActivationContext,
} from "@/lib/open-loops/open-loop-activation";
import { pickOpenLoopResurfacingLine } from "@/lib/open-loops/open-loop-resurfacing-lines";
import {
  getCachedUnresolvedThread,
  hasCachedUnresolvedThreadLanguage,
} from "@/lib/open-loops/unresolved-cache";
import {
  readAllOpenLoopsFromStore,
  readActiveOpenLoopsFromStore,
  readEntryOpenLoopContinuityLineFromStore,
  readHasActiveOpenLoopForEntry,
  readIsOpenLoopPromptDismissed,
  readOpenLoopByIdFromStore,
  readOpenLoopsForEntryFromStore,
  readOpenLoopPresentationFromStore,
  readOpenLoopsWithMetaFromStore,
  readPrimaryAnchorPhrase,
  readShouldShowOpenLoopPrompt,
} from "@/lib/open-loops/open-loop-storage";
import { pickOpenLoopsToResurface } from "@/lib/open-loops/open-loop-resurfacing";
import {
  pickOpenLoopReturnOffer,
  type OpenLoopReturnOffer,
} from "@/lib/open-loops/open-loop-return-prompt";
import { getCachedQuietEntryPresentation, getCachedRevisitExperience } from "@/lib/performance/resurfacing-cache";
import {
  getTierSnapshot,
  hasEntitlement,
  listEntitlementRecords,
} from "@/lib/entitlement/entitlements";
import { getPaymentStackAudit } from "@/lib/entitlement/payment-stack";
import { runReadOnly } from "@/lib/runtime/render-safe";
import type { EntitlementId, TierSnapshot } from "@/types/entitlement";
import type { UnresolvedThreadSignal } from "@/lib/open-loops/unresolved-detect-core";
import type { JournalEntry } from "@/types/journal";
import type { QuietEntryPresentation } from "@/lib/refinement/quiet-presentation";
import type { RevisitExperiencePresentation } from "@/lib/refinement/revisit-experience";
import type {
  OpenLoop,
  OpenLoopPresentation,
  OpenLoopWithEntryMeta,
} from "@/types/open-loop";

// —— Entitlements (read-only) ——

export function readHasEntitlement(id: EntitlementId): boolean {
  return runReadOnly("readHasEntitlement", () => hasEntitlement(id));
}

export function readTierSnapshot(): TierSnapshot {
  return runReadOnly("readTierSnapshot", getTierSnapshot);
}

export function readEntitlementRecords() {
  return runReadOnly("readEntitlementRecords", listEntitlementRecords);
}

export function readPaymentStackAudit() {
  return runReadOnly("readPaymentStackAudit", getPaymentStackAudit);
}

// —— Open loops (read-only) ——

export function readAllOpenLoops(): OpenLoop[] {
  return runReadOnly("readAllOpenLoops", readAllOpenLoopsFromStore);
}

export function readActiveOpenLoops(): OpenLoop[] {
  return runReadOnly("readActiveOpenLoops", readActiveOpenLoopsFromStore);
}

export function readOpenLoopById(openLoopId: string): OpenLoop | null {
  return runReadOnly("readOpenLoopById", () => readOpenLoopByIdFromStore(openLoopId));
}

export function readOpenLoopsForEntry(entryId: string): OpenLoop[] {
  return runReadOnly("readOpenLoopsForEntry", () =>
    readOpenLoopsForEntryFromStore(entryId),
  );
}

export function readHasActiveOpenLoop(entryId: string): boolean {
  return runReadOnly("readHasActiveOpenLoop", () => readHasActiveOpenLoopForEntry(entryId));
}

export function readOpenLoopPromptDismissed(entryId: string): boolean {
  return runReadOnly("readOpenLoopPromptDismissed", () =>
    readIsOpenLoopPromptDismissed(entryId),
  );
}

export function readShouldOfferOpenLoopPrompt(
  entryId: string,
  transcript: string,
  options?: { isRevisit?: boolean },
): boolean {
  return runReadOnly("readShouldOfferOpenLoopPrompt", () =>
    readShouldShowOpenLoopPrompt(entryId, transcript, options),
  );
}

export function readOpenLoopPresentation(loop: OpenLoop): OpenLoopPresentation {
  return runReadOnly("readOpenLoopPresentation", () =>
    readOpenLoopPresentationFromStore(loop),
  );
}

export function readOpenLoopPresentations(activeOnly = true): OpenLoopPresentation[] {
  return runReadOnly("readOpenLoopPresentations", () => {
    const loops = activeOnly
      ? readActiveOpenLoopsFromStore()
      : readAllOpenLoopsFromStore();
    return loops.map((loop) => readOpenLoopPresentationFromStore(loop));
  });
}

export function readOpenLoopsWithMeta(activeOnly = true): OpenLoopWithEntryMeta[] {
  return runReadOnly("readOpenLoopsWithMeta", () =>
    readOpenLoopsWithMetaFromStore(activeOnly),
  );
}

export function readEntryOpenLoopContinuityLine(entryId: string): string | null {
  return runReadOnly("readEntryOpenLoopContinuityLine", () =>
    readEntryOpenLoopContinuityLineFromStore(entryId),
  );
}

export function readOpenLoopAnchorPhrase(loop: OpenLoop): string {
  return runReadOnly("readOpenLoopAnchorPhrase", () => readPrimaryAnchorPhrase(loop));
}

// —— Unresolved detection (read-only, cached) ——

export function readUnresolvedThread(transcript: string): UnresolvedThreadSignal | null {
  return runReadOnly("readUnresolvedThread", () => getCachedUnresolvedThread(transcript));
}

export function readHasUnresolvedLanguage(transcript: string): boolean {
  return runReadOnly("readHasUnresolvedLanguage", () =>
    hasCachedUnresolvedThreadLanguage(transcript),
  );
}

// —— Activation (read-only) ——

export function readOpenLoopActivation(
  entry: JournalEntry,
  options?: { isRevisit?: boolean; heavyReady?: boolean | null },
): OpenLoopActivationContext {
  return runReadOnly("readOpenLoopActivation", () =>
    resolveOpenLoopActivation(entry, options),
  );
}

export function readOpenLoopActivationAudit(
  entry: JournalEntry,
  options?: {
    isRevisit?: boolean;
    heavyReady?: boolean | null;
    dismissed?: boolean;
    hasLoop?: boolean;
  },
): OpenLoopActivationAudit {
  return runReadOnly("readOpenLoopActivationAudit", () =>
    auditOpenLoopActivation(entry, options),
  );
}

// —— Resurfacing candidate selection (read-only) ——

export function readOpenLoopResurfacingLine(loop: OpenLoop, now = Date.now()): string | null {
  return runReadOnly("readOpenLoopResurfacingLine", () =>
    pickOpenLoopResurfacingLine(loop, now),
  );
}

export function readOpenLoopsToResurface(limit = 2, now = Date.now()): OpenLoop[] {
  return runReadOnly("readOpenLoopsToResurface", () => pickOpenLoopsToResurface(limit, now));
}

export function readOpenLoopReturnOffer(
  entries?: JournalEntry[],
  now = Date.now(),
): OpenLoopReturnOffer | null {
  return runReadOnly("readOpenLoopReturnOffer", () =>
    pickOpenLoopReturnOffer(entries, now),
  );
}

export type { OpenLoopReturnOffer };

// —— Entry presentation (read-only selectors) ——

export function readCachedQuietEntryPresentation(
  entries: JournalEntry[],
  entryId: string,
  limits: {
    changeMoments: number;
    familiarity: number;
    familiarityResurfacing: number;
    resurfacing: number;
  },
  entriesVersion: number,
): QuietEntryPresentation {
  return runReadOnly("readCachedQuietEntryPresentation", () =>
    getCachedQuietEntryPresentation(entries, entryId, limits, entriesVersion),
  );
}

export function readCachedRevisitExperience(
  entries: JournalEntry[],
  entryId: string,
  limits: {
    changeMoments: number;
    familiarityResurfacing: number;
    resurfacing: number;
  },
  entriesVersion: number,
): RevisitExperiencePresentation {
  return runReadOnly("readCachedRevisitExperience", () =>
    getCachedRevisitExperience(entries, entryId, limits, entriesVersion),
  );
}
