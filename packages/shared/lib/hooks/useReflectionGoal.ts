"use client";

import { useCallback, useEffect, useState } from "react";

import { getReflectionGoal, setReflectionGoal } from "@/lib/reflection-goal";
import type { ReflectionGoal } from "@/types/reflection-goal";

export function useReflectionGoal() {
  const [goal, setGoalState] = useState<ReflectionGoal>("off");

  useEffect(() => {
    const sync = () => setGoalState(getReflectionGoal());
    sync();
    window.addEventListener("voicememory:reflection-goal", sync);
    return () => window.removeEventListener("voicememory:reflection-goal", sync);
  }, []);

  const setGoal = useCallback((next: ReflectionGoal) => {
    setReflectionGoal(next);
    setGoalState(next);
  }, []);

  return { goal, setGoal };
}
