"use client";

import { useEffect, useState } from "react";

import { Button } from "@/components/ui/button";
import {
  saveTheoryCuriosityAnswer,
  shouldAskTheoryCuriosity,
  THEORY_CURIOSITY_LABELS,
  THEORY_CURIOSITY_QUESTION,
} from "@/lib/metrics/theory-curiosity";
import type { TheoryCuriosityAnswer } from "@/types/personal-theory";

const OPTIONS: TheoryCuriosityAnswer[] = ["yes", "maybe", "no"];

interface TheoryCuriosityPromptProps {
  className?: string;
}

export function TheoryCuriosityPrompt({ className = "" }: TheoryCuriosityPromptProps) {
  const [visible, setVisible] = useState(false);
  const [dismissed, setDismissed] = useState(false);

  useEffect(() => {
    const id = requestAnimationFrame(() => {
      setVisible(shouldAskTheoryCuriosity(3));
    });
    return () => cancelAnimationFrame(id);
  }, []);

  if (!visible || dismissed) return null;

  const submit = (answer: TheoryCuriosityAnswer) => {
    saveTheoryCuriosityAnswer(answer);
    setDismissed(true);
  };

  return (
    <div
      className={`rounded-2xl border border-white/10 bg-zinc-900/50 px-4 py-4 ${className}`}
      data-testid="theory-curiosity-prompt"
    >
      <p className="text-sm leading-relaxed text-zinc-300">{THEORY_CURIOSITY_QUESTION}</p>
      <div className="mt-3 flex flex-wrap gap-2">
        {OPTIONS.map((option) => (
          <Button
            key={option}
            type="button"
            size="sm"
            variant="ghost"
            className="text-xs"
            onClick={() => submit(option)}
          >
            {THEORY_CURIOSITY_LABELS[option]}
          </Button>
        ))}
      </div>
    </div>
  );
}
