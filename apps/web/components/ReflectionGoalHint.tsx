"use client";

import { useEffect, useState } from "react";

import {
  recordReflectionGoalHintShown,
  reflectionGoalHint,
} from "@/lib/reflection-goal";
import { useReflectionGoal } from "@/lib/hooks/useReflectionGoal";

export function ReflectionGoalHint() {
  const { goal } = useReflectionGoal();
  const [hint, setHint] = useState<string | null>(null);

  useEffect(() => {
    const id = requestAnimationFrame(() => {
      setHint(reflectionGoalHint(goal));
    });
    return () => cancelAnimationFrame(id);
  }, [goal]);

  useEffect(() => {
    if (hint) recordReflectionGoalHintShown();
  }, [hint]);

  if (!hint) return null;

  return (
    <p className="px-1 py-1 text-xs leading-relaxed text-zinc-600">{hint}</p>
  );
}
