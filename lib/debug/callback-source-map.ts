import type { CallbackReviewKind } from "@/types/callback-quality-review";

export interface CallbackSourceLocation {
  file: string;
  function: string;
  note?: string;
}

const KIND_SOURCE: Record<CallbackReviewKind, CallbackSourceLocation> = {
  memory_callback: {
    file: "lib/patterns/memory-notes.ts",
    function: "buildMemoryNotesReport",
  },
  then_vs_now: {
    file: "lib/patterns/continuity-moments.ts",
    function: "buildContinuityMomentsReport",
  },
  continuity_line: {
    file: "lib/patterns/memory-notes.ts",
    function: "buildMemoryNotesReport",
    note: "landmarks",
  },
  resurfacing: {
    file: "lib/memory/resurfacing.ts",
    function: "buildResurfacingReport",
  },
  revisitation: {
    file: "lib/memory/revisitation.ts",
    function: "buildRevisitationReport",
  },
  change_moment: {
    file: "lib/memory/change-moments.ts",
    function: "buildChangeMomentsReport",
  },
  milestone: {
    file: "lib/memory/milestones.ts",
    function: "buildEmotionalMilestonesReport",
  },
  relationship_continuity: {
    file: "lib/memory/relationship-continuity.ts",
    function: "buildRelationshipContinuityReport",
  },
  archive_growth: {
    file: "lib/memory/archive-growth.ts",
    function: "buildArchiveGrowthReport",
  },
  memory_reminder: {
    file: "lib/memory/memory-reminders.ts",
    function: "buildMemoryRemindersReport",
  },
  continuity_depth: {
    file: "lib/memory/continuity-depth.ts",
    function: "buildContinuityDepthReport",
  },
  familiarity: {
    file: "lib/memory/familiarity.ts",
    function: "buildFamiliarityReport",
  },
  familiarity_resurfacing: {
    file: "lib/memory/familiarity-resurfacing.ts",
    function: "buildFamiliarityResurfacingReport",
  },
  rhythm: {
    file: "lib/memory/rhythm-memory.ts",
    function: "buildRhythmReport",
  },
  time_memory: {
    file: "lib/memory/time-memory.ts",
    function: "buildTimeMemoryReport",
  },
};

const ID_PREFIX_SOURCE: Array<{ prefix: string; location: CallbackSourceLocation }> = [
  {
    prefix: "continuity-",
    location: {
      file: "lib/conversation/conversation-continuity.ts",
      function: "buildConversationContinuityReport",
    },
  },
  {
    prefix: "recovery-",
    location: {
      file: "lib/memory/recovery-memory.ts",
      function: "detectRecoveryMoments",
    },
  },
  {
    prefix: "followup-",
    location: {
      file: "lib/conversation/followup-prompts.ts",
      function: "buildFollowupPrompt",
    },
  },
];

/** Resolve the generator module for a callback — debug only. */
export function resolveCallbackSource(
  kind: CallbackReviewKind,
  callbackId: string,
): CallbackSourceLocation {
  for (const row of ID_PREFIX_SOURCE) {
    if (callbackId.startsWith(row.prefix)) return row.location;
  }
  return KIND_SOURCE[kind];
}
