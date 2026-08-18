"use client";

import { useMemo, useState } from "react";

import { ArchiveQuestionAnswerCard } from "@/components/archive/ArchiveQuestionAnswerCard";
import {
  ARCHIVE_QUESTION_BUTTONS,
  QUESTION_THE_ARCHIVE_HEADLINE,
  QUESTION_THE_ARCHIVE_LEAD,
} from "@/lib/archive/archive-question-copy";
import {
  answerForQuestion,
  buildArchiveQuestionAnswers,
} from "@/lib/archive/archive-question-engine";
import { markArchiveQuestionEngaged } from "@/lib/archive/archive-milestone-storage";
import { ARCHIVE_TYPO } from "@/lib/design/archive-typography";
import { useClientHydrated } from "@/lib/hooks/use-client-hydrated";
import { cn } from "@/lib/utils";
import type { ArchiveQuestionId } from "@/types/archive-question";
import type { JournalEntry } from "@/types/journal";

type QuestionTheArchiveProps = {
  entriesOverride?: JournalEntry[];
  className?: string;
};

/** Structured interrogation — the archive answers about itself. */
export function QuestionTheArchive({
  entriesOverride,
  className = "",
}: QuestionTheArchiveProps) {
  const hydrated = useClientHydrated();
  const [activeId, setActiveId] = useState<ArchiveQuestionId | null>(null);

  const answers = useMemo(
    () => (hydrated ? buildArchiveQuestionAnswers(entriesOverride) : null),
    [hydrated, entriesOverride],
  );

  if (!answers) return null;

  const activeAnswer = activeId ? answerForQuestion(answers, activeId) : null;

  return (
    <section
      className={cn(
        "rounded-2xl border border-white/10 bg-zinc-900/40 px-4 py-4",
        className,
      )}
      data-testid="question-the-archive"
    >
      <h2 className={ARCHIVE_TYPO.sectionTitle}>{QUESTION_THE_ARCHIVE_HEADLINE}</h2>
      <p className={`${ARCHIVE_TYPO.caption} mt-2`}>{QUESTION_THE_ARCHIVE_LEAD}</p>

      <div className="mt-4 flex flex-wrap gap-2" role="group" aria-label="Archive questions">
        {ARCHIVE_QUESTION_BUTTONS.map((btn) => (
          <button
            key={btn.id}
            type="button"
            data-testid={`archive-question-btn-${btn.id}`}
            aria-pressed={activeId === btn.id}
            onClick={() => {
              setActiveId((current) => {
                const next = current === btn.id ? null : btn.id;
                if (next) markArchiveQuestionEngaged();
                return next;
              });
            }}
            className={cn(
              "rounded-full border px-3 py-1.5 text-xs font-medium transition-colors",
              activeId === btn.id
                ? "border-violet-400/50 bg-violet-500/25 text-violet-100"
                : "border-white/10 bg-black/20 text-zinc-400 hover:border-violet-500/30 hover:text-zinc-200",
            )}
          >
            {btn.label}
          </button>
        ))}
      </div>

      {activeAnswer ? (
        <div className="mt-4">
          <ArchiveQuestionAnswerCard answer={activeAnswer} />
        </div>
      ) : null}
    </section>
  );
}
