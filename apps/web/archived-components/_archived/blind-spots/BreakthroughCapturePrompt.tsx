"use client";

import { useState } from "react";

import { Button } from "@/archived-components/_archived/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/archived-components/_archived/ui/card";
import { saveBreakthroughCapture } from "@/lib/blind-spots/breakthrough-capture";
import { observeFirstValueMoment } from "@/lib/retention/first-value-moments";
import { BLIND_SPOT_PAGE } from "@/lib/blind-spots/blind-spot-copy";
import type { BlindSpotReaction } from "@/types/blind-spot";

interface BreakthroughCapturePromptProps {
  feedbackId: string;
  reviewId: string;
  reaction: "surprising" | "uncomfortably_accurate";
}

export function BreakthroughCapturePrompt({
  feedbackId,
  reviewId,
  reaction,
}: BreakthroughCapturePromptProps) {
  const [phrase, setPhrase] = useState("");
  const [saved, setSaved] = useState(false);

  const submit = () => {
    const record = saveBreakthroughCapture({ feedbackId, reviewId, reaction, phrase });
    if (record) {
      observeFirstValueMoment("breakthrough_captured");
      setSaved(true);
    }
  };

  if (saved) {
    return (
      <p className="text-xs text-zinc-600">Saved — helps identify what felt genuinely valuable.</p>
    );
  }

  return (
    <Card className="border-violet-500/20 bg-violet-950/15">
      <CardHeader className="pb-2">
        <CardTitle className="text-sm font-medium text-violet-200/90">
          {BLIND_SPOT_PAGE.breakthroughPrompt}
        </CardTitle>
        <p className="text-xs text-zinc-500">{BLIND_SPOT_PAGE.breakthroughHelper}</p>
      </CardHeader>
      <CardContent className="space-y-2">
        <textarea
          value={phrase}
          onChange={(e) => setPhrase(e.target.value)}
          rows={2}
          placeholder="A phrase or moment that landed…"
          className="w-full rounded-xl border border-white/10 bg-black/20 px-3 py-2 text-sm text-zinc-200 placeholder:text-zinc-600 focus:border-violet-400/40 focus:outline-none"
        />
        <Button type="button" size="sm" variant="secondary" onClick={submit} disabled={!phrase.trim()}>
          Save
        </Button>
      </CardContent>
    </Card>
  );
}
