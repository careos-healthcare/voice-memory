"use client";

import { useMemo } from "react";

import { ArchiveImplicationsCard } from "@/components/archive/ArchiveImplicationsCard";
import { ArchiveLatestMilestone } from "@/components/archive/ArchiveLatestMilestone";
import { ArchiveMilestoneFeed } from "@/components/archive/ArchiveMilestoneFeed";
import { ArchiveMilestoneTimeline } from "@/components/archive/ArchiveMilestoneTimeline";
import { QuestionTheArchive } from "@/components/archive/QuestionTheArchive";
import { ArchiveWatchCard } from "@/components/archive/ArchiveWatchCard";
import { BeliefChangeTimeline } from "@/components/archive/BeliefChangeTimeline";
import { EvidenceLocker } from "@/components/archive/EvidenceLocker";
import { buildArchiveStateObject } from "@/lib/archive/archive-state-object";
import {
  ARCHIVE_CASE_FILE_BELIEF,
  ARCHIVE_CASE_FILE_CHANGES,
  ARCHIVE_CASE_FILE_EVIDENCE,
  ARCHIVE_CASE_FILE_TITLE,
} from "@/lib/archive/archive-case-file-copy";
import {
  DISCLOSURE_EVIDENCE_SECTION,
  DISCLOSURE_TIMELINE_SECTION,
} from "@/lib/archive/archive-disclosure-copy";
import {
  resolveArchiveDisclosureLevel,
  isDisclosureLevelAtLeast,
} from "@/lib/archive/archive-disclosure-level";
import { buildArchiveBeliefView } from "@/lib/archive/archive-belief";
import { ARCHIVE_TYPO } from "@/lib/design/archive-typography";
import { ARCHIVE_SPACE } from "@/lib/design/archive-spacing";
import { useClientHydrated } from "@/lib/hooks/use-client-hydrated";
import { cn } from "@/lib/utils";
import type { ArchiveDisclosureLevel } from "@/types/archive-disclosure-level";
import type { JournalEntry } from "@/types/journal";

type ProgressiveArchiveHomeProps = {
  entriesOverride?: JournalEntry[];
  className?: string;
};

function V3Section({
  title,
  body,
  testId,
}: {
  title: string;
  body: string;
  testId: string;
}) {
  return (
    <section
      className="rounded-2xl border border-white/10 bg-zinc-900/40 px-4 py-4"
      data-testid={testId}
    >
      <h2 className={ARCHIVE_TYPO.sectionTitle}>{title}</h2>
      <p className={`${ARCHIVE_TYPO.body} mt-2 text-zinc-200`}>{body}</p>
    </section>
  );
}

/** Level 1–2 archive home — belief, why, change, watch; L2 adds evidence + timeline. */
export function ProgressiveArchiveHome({
  entriesOverride,
  className = "",
}: ProgressiveArchiveHomeProps) {
  const hydrated = useClientHydrated();

  const disclosure = useMemo(() => {
    if (!hydrated) return null;
    return resolveArchiveDisclosureLevel();
  }, [hydrated, entriesOverride]);

  const state = useMemo(
    () => (hydrated ? buildArchiveStateObject(entriesOverride) : null),
    [hydrated, entriesOverride],
  );

  const beliefView = useMemo(
    () => (hydrated ? buildArchiveBeliefView(entriesOverride) : null),
    [hydrated, entriesOverride],
  );

  if (!state || !disclosure) return null;

  const level: ArchiveDisclosureLevel = disclosure.level;
  const showL2 = isDisclosureLevelAtLeast(level, "L2_ENGAGED");

  return (
    <div
      className={cn("space-y-4", ARCHIVE_SPACE.sectionBreath, className)}
      data-testid="progressive-archive-home"
      data-archive-disclosure-level={level}
    >
      <p
        className="font-mono text-[10px] uppercase tracking-[0.28em] text-zinc-500"
        data-testid="archive-case-file-title"
      >
        {ARCHIVE_CASE_FILE_TITLE}
      </p>

      <header
        className="rounded-2xl border border-violet-500/40 bg-gradient-to-br from-violet-950/55 via-zinc-950/90 to-zinc-950 px-4 py-4"
        data-testid="archive-v3-current-belief"
      >
        <p className="font-mono text-[10px] uppercase tracking-[0.25em] text-violet-300/90">
          {ARCHIVE_CASE_FILE_BELIEF}
        </p>
        <p className="mt-3 text-lg font-medium leading-snug text-zinc-50 sm:text-xl">
          {state.belief}
        </p>
      </header>

      <V3Section
        title={ARCHIVE_CASE_FILE_EVIDENCE}
        body={state.evidenceSummary}
        testId="archive-v3-why"
      />
      <V3Section
        title={ARCHIVE_CASE_FILE_CHANGES}
        body={state.changeSummary}
        testId="archive-v3-what-changed"
      />
      <ArchiveImplicationsCard entriesOverride={entriesOverride} />
      <ArchiveWatchCard watchItem={state.watchItem} />
      <ArchiveLatestMilestone entriesOverride={entriesOverride} />
      <ArchiveMilestoneFeed entriesOverride={entriesOverride} />
      <QuestionTheArchive entriesOverride={entriesOverride} />

      {showL2 ? (
        <>
          <section
            className="rounded-2xl border border-white/10 bg-zinc-900/40 px-4 py-4"
            data-testid="archive-disclosure-evidence"
          >
            <h2 className={ARCHIVE_TYPO.sectionTitle}>{DISCLOSURE_EVIDENCE_SECTION}</h2>
            <div className="mt-3" id="evidence-locker">
              <EvidenceLocker entriesOverride={entriesOverride} />
            </div>
          </section>
          <section
            className="rounded-2xl border border-white/10 bg-zinc-900/40 px-4 py-4"
            data-testid="archive-disclosure-timeline"
          >
            <h2 className={ARCHIVE_TYPO.sectionTitle}>{DISCLOSURE_TIMELINE_SECTION}</h2>
            <div className="mt-3 max-h-52 overflow-y-auto">
              {beliefView ? (
                <BeliefChangeTimeline
                  className="!border-0 !bg-transparent !p-0"
                  entriesOverride={entriesOverride}
                  theoryId={beliefView.theoryId}
                />
              ) : (
                <p className={ARCHIVE_TYPO.caption}>Timeline fills in as beliefs move.</p>
              )}
            </div>
          </section>
          <ArchiveMilestoneTimeline entriesOverride={entriesOverride} />
        </>
      ) : null}
    </div>
  );
}
