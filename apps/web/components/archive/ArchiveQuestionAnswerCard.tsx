"use client";

import { ARCHIVE_TYPO } from "@/lib/design/archive-typography";
import type { ArchiveQuestionAnswer } from "@/types/archive-question";

type ArchiveQuestionAnswerCardProps = {
  answer: ArchiveQuestionAnswer;
  className?: string;
};

/** Structured archive answer — explanation and evidence only. */
export function ArchiveQuestionAnswerCard({
  answer,
  className = "",
}: ArchiveQuestionAnswerCardProps) {
  return (
    <article
      className={`rounded-xl border border-violet-500/25 bg-violet-950/15 px-4 py-4 ${className}`}
      data-testid="archive-question-answer-card"
      data-question-id={answer.questionId}
    >
      <p className="text-xs uppercase tracking-wide text-violet-300/80">Question</p>
      <p className={`${ARCHIVE_TYPO.body} mt-1 font-medium text-zinc-100`}>
        {answer.questionLabel}
      </p>

      <p className="mt-4 text-xs uppercase tracking-wide text-zinc-600">Archive answer</p>
      <ul className={`${ARCHIVE_TYPO.body} mt-2 space-y-1.5 text-zinc-300`}>
        {answer.answerLines.map((line) => (
          <li key={line}>{line}</li>
        ))}
      </ul>

      {answer.evidenceLines.length > 0 ? (
        <div className="mt-4 border-t border-white/10 pt-4">
          <p className="text-xs uppercase tracking-wide text-zinc-600">Evidence</p>
          <ul className={`${ARCHIVE_TYPO.caption} mt-2 space-y-2 italic text-zinc-500`}>
            {answer.evidenceLines.map((line) => (
              <li key={line} className="border-l-2 border-zinc-700 pl-3">
                {line}
              </li>
            ))}
          </ul>
        </div>
      ) : null}
    </article>
  );
}
