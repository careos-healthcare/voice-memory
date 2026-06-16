"use client";

import { useEffect, useRef, useState } from "react";

import { persistArchiveFollowupAnswer } from "@/lib/archive/archive-followup-storage";
import { IMMEDIATE_ENGAGEMENT_HEADING } from "@/lib/archive/immediate-engagement";
import {
  trackFollowupAnswered,
  trackFollowupShown,
} from "@/lib/metrics/immediate-engagement-events";
import type {
  ArchiveFollowupAnswerValue,
  ImmediateEngagementPayload,
} from "@/types/immediate-engagement";

const ANSWER_LABELS: Record<ArchiveFollowupAnswerValue, string> = {
  yes: "Yes",
  no: "No",
  not_sure: "Not sure",
  skip: "Skip",
};

interface ImmediateEngagementPanelProps {
  engagement: ImmediateEngagementPayload;
  className?: string;
}

export function ImmediateEngagementPanel({
  engagement,
  className = "",
}: ImmediateEngagementPanelProps) {
  const [answered, setAnswered] = useState<ArchiveFollowupAnswerValue | null>(null);
  const shownRef = useRef(false);

  useEffect(() => {
    if (shownRef.current) return;
    shownRef.current = true;
    trackFollowupShown({
      followUpId: engagement.followUpId,
      entryId: engagement.entryId,
      noticeKind: engagement.noticeKind,
    });
  }, [engagement]);

  const submit = (answer: ArchiveFollowupAnswerValue) => {
    if (answered) return;
    setAnswered(answer);
    persistArchiveFollowupAnswer({
      followUpId: engagement.followUpId,
      entryId: engagement.entryId,
      noticeKind: engagement.noticeKind,
      answer,
    });
    trackFollowupAnswered({
      followUpId: engagement.followUpId,
      entryId: engagement.entryId,
      noticeKind: engagement.noticeKind,
    });
  };

  return (
    <div
      className={`rounded-2xl border border-zinc-700/50 bg-zinc-900/40 px-4 py-4 text-left ${className}`}
      data-testid="immediate-engagement-panel"
      data-notice-kind={engagement.noticeKind}
    >
      <p className="text-xs uppercase tracking-[0.16em] text-zinc-500">
        {IMMEDIATE_ENGAGEMENT_HEADING}
      </p>
      <p className="mt-2 text-xs text-violet-300/80">{engagement.noticeCategory}</p>
      <p className="mt-1 text-sm leading-relaxed text-zinc-100">{engagement.noticeDetail}</p>

      {!answered ? (
        <div className="mt-4 space-y-3">
          <p className="text-sm leading-relaxed text-zinc-400">{engagement.followUpQuestion}</p>
          <div className="flex flex-wrap gap-2">
            {(Object.keys(ANSWER_LABELS) as ArchiveFollowupAnswerValue[]).map((value) => (
              <button
                key={value}
                type="button"
                onClick={() => submit(value)}
                className="rounded-full border border-zinc-600/80 px-3 py-1.5 text-xs text-zinc-300 hover:border-zinc-500 hover:text-zinc-100"
              >
                {ANSWER_LABELS[value]}
              </button>
            ))}
          </div>
        </div>
      ) : (
        <p className="mt-3 text-xs text-zinc-600">Recorded for your archive.</p>
      )}
    </div>
  );
}
