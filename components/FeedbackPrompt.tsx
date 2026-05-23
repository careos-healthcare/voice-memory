"use client";

import { useState } from "react";
import { ThumbsDown, ThumbsUp } from "lucide-react";

import { Button } from "@/components/ui/button";
import {
  getFeedbackForTarget,
  saveFeedbackRecord,
  type FeedbackKind,
  type FeedbackRating,
} from "@/lib/feedback-storage";

interface FeedbackPromptProps {
  kind: FeedbackKind;
  targetKey: string;
  label?: string;
  className?: string;
}

export function FeedbackPrompt({
  kind,
  targetKey,
  label = "Was this reflection useful?",
  className,
}: FeedbackPromptProps) {
  const [existing, setExisting] = useState(() =>
    typeof window !== "undefined"
      ? getFeedbackForTarget(kind, targetKey)
      : undefined,
  );
  const [comment, setComment] = useState(existing?.comment ?? "");
  const [showComment, setShowComment] = useState(false);
  const [saved, setSaved] = useState(Boolean(existing));

  const submit = (rating: FeedbackRating) => {
    const record = saveFeedbackRecord({
      kind,
      targetKey,
      rating,
      comment: showComment ? comment : undefined,
    });
    setExisting(record);
    setSaved(true);
  };

  return (
    <div
      className={`rounded-2xl border border-white/10 bg-white/[0.02] px-4 py-4 ${className ?? ""}`}
    >
      <p className="text-sm text-zinc-300">{label}</p>
      <div className="mt-3 flex flex-wrap items-center gap-2">
        <Button
          type="button"
          size="sm"
          variant={existing?.rating === "up" ? "default" : "secondary"}
          onClick={() => submit("up")}
        >
          <ThumbsUp className="h-4 w-4" />
          Yes
        </Button>
        <Button
          type="button"
          size="sm"
          variant={existing?.rating === "down" ? "default" : "secondary"}
          onClick={() => submit("down")}
        >
          <ThumbsDown className="h-4 w-4" />
          Not really
        </Button>
        {!showComment ? (
          <Button
            type="button"
            size="sm"
            variant="ghost"
            className="text-zinc-500"
            onClick={() => setShowComment(true)}
          >
            Add a note
          </Button>
        ) : null}
      </div>
      {showComment ? (
        <div className="mt-3 space-y-2">
          <textarea
            value={comment}
            onChange={(event) => setComment(event.target.value)}
            placeholder="Optional — what worked or didn't?"
            rows={2}
            className="w-full rounded-xl border border-white/10 bg-black/20 px-3 py-2 text-sm text-zinc-200 placeholder:text-zinc-600 focus:border-violet-400/40 focus:outline-none"
          />
          {existing ? (
            <Button
              type="button"
              size="sm"
              variant="ghost"
              onClick={() =>
                submit(existing.rating)
              }
            >
              Update note
            </Button>
          ) : null}
        </div>
      ) : null}
      {saved ? (
        <p className="mt-2 text-xs text-zinc-600">Saved locally — helps us improve launch quality.</p>
      ) : null}
    </div>
  );
}
