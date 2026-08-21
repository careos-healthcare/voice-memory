"use client";

import { useEffect, useState } from "react";

import { Button } from "@/archived-components/_archived/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/archived-components/_archived/ui/card";
import { trackTestimonialPromptSeen, trackTestimonialSubmitted } from "@/lib/distribution/distribution-events";
import {
  TESTIMONIAL_CAPTURE_QUESTION,
  hasTestimonialForMoment,
  isMajorTestimonialMoment,
  saveDistributionTestimonial,
} from "@/lib/distribution/testimonial-store";
import { latestDistributionMoment } from "@/lib/distribution/transformation-moments";
import type { TransformationMomentType } from "@/types/distribution";

const TESTIMONIAL_PROMPT_LAST_KEY = "voicememory_testimonial_prompt_last";
const COOLDOWN_MS = 21 * 24 * 60 * 60 * 1000;

type TestimonialCapturePromptProps = {
  className?: string;
  momentType?: TransformationMomentType;
};

export function TestimonialCapturePrompt({
  className = "",
  momentType: momentTypeProp,
}: TestimonialCapturePromptProps) {
  const [visible, setVisible] = useState(false);
  const [text, setText] = useState("");
  const [rating, setRating] = useState<1 | 2 | 3 | 4 | 5>(4);
  const moment =
    momentTypeProp ??
    latestDistributionMoment()?.type ??
    null;

  useEffect(() => {
    if (!moment || !isMajorTestimonialMoment(moment)) return;
    if (hasTestimonialForMoment(moment)) return;
    const last = localStorage.getItem(TESTIMONIAL_PROMPT_LAST_KEY);
    if (last && Date.now() - new Date(last).getTime() < COOLDOWN_MS) return;
    setVisible(true);
    localStorage.setItem(TESTIMONIAL_PROMPT_LAST_KEY, new Date().toISOString());
    trackTestimonialPromptSeen({ momentType: moment });
  }, [moment]);

  if (!visible || !moment) return null;

  const submit = () => {
    const trimmed = text.trim();
    if (trimmed.length < 8) return;
    saveDistributionTestimonial({ momentType: moment, text: trimmed, rating });
    trackTestimonialSubmitted({ momentType: moment, rating: String(rating) });
    setVisible(false);
  };

  return (
    <Card
      className={`border-violet-500/25 bg-violet-950/15 ${className}`}
      data-testid="testimonial-capture-prompt"
    >
      <CardHeader className="pb-2">
        <CardTitle className="text-sm font-medium text-violet-100/90">
          {TESTIMONIAL_CAPTURE_QUESTION}
        </CardTitle>
      </CardHeader>
      <CardContent className="space-y-3">
        <textarea
          value={text}
          onChange={(e) => setText(e.target.value)}
          rows={3}
          className="w-full rounded-lg border border-white/10 bg-zinc-950/80 px-3 py-2 text-sm text-zinc-200"
          placeholder="A sentence is enough — no reflection text needed."
        />
        <div className="flex items-center gap-2">
          <label className="text-xs text-zinc-500">How much did it surprise you?</label>
          <select
            value={rating}
            onChange={(e) => setRating(Number(e.target.value) as 1 | 2 | 3 | 4 | 5)}
            className="rounded border border-white/10 bg-zinc-950 px-2 py-1 text-xs text-zinc-300"
          >
            {[1, 2, 3, 4, 5].map((n) => (
              <option key={n} value={n}>
                {n}
              </option>
            ))}
          </select>
        </div>
        <div className="flex flex-wrap gap-2">
          <Button type="button" size="sm" onClick={submit}>
            Save
          </Button>
          <button
            type="button"
            className="text-xs text-zinc-600 hover:text-zinc-400"
            onClick={() => setVisible(false)}
          >
            Not now
          </button>
        </div>
      </CardContent>
    </Card>
  );
}
