"use client";

import {
  WHAT_ARCHIVE_CAN_ANSWER_BULLETS,
  WHAT_ARCHIVE_CAN_ANSWER_HEADLINE,
} from "@/lib/archive/what-archive-can-answer-copy";

interface WhatThisArchiveCanAnswerProps {
  className?: string;
}

export function WhatThisArchiveCanAnswer({ className = "" }: WhatThisArchiveCanAnswerProps) {
  return (
    <div
      className={`rounded-2xl border border-zinc-700/45 bg-zinc-900/35 px-4 py-4 text-left ${className}`}
      data-testid="what-archive-can-answer"
    >
      <p className="text-xs uppercase tracking-[0.16em] text-zinc-500">
        {WHAT_ARCHIVE_CAN_ANSWER_HEADLINE}
      </p>
      <ul className="mt-3 list-inside list-disc space-y-1.5 text-sm text-zinc-400">
        {WHAT_ARCHIVE_CAN_ANSWER_BULLETS.map((item) => (
          <li key={item}>{item}</li>
        ))}
      </ul>
    </div>
  );
}
