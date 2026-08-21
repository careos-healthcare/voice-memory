"use client";

import { REFLECTION_GOAL_OPTIONS } from "@/lib/reflection-goal";
import { useReflectionGoal } from "@/lib/hooks/useReflectionGoal";
import type { ReflectionGoal } from "@/types/reflection-goal";

export function ReflectionGoalSetting() {
  const { goal, setGoal } = useReflectionGoal();

  return (
    <div className="space-y-2">
      {REFLECTION_GOAL_OPTIONS.map((option) => (
        <label
          key={option.value}
          className="flex cursor-pointer items-start gap-3 rounded-2xl border border-white/10 bg-white/[0.02] p-4 transition-colors hover:bg-white/[0.04]"
        >
          <input
            type="radio"
            name="reflection-goal"
            checked={goal === option.value}
            onChange={() => setGoal(option.value as ReflectionGoal)}
            className="mt-1 h-4 w-4 border-white/20 bg-zinc-900 text-violet-500 focus:ring-violet-500/30"
          />
          <span className="min-w-0 flex-1">
            <span className="block text-sm font-medium text-white">{option.label}</span>
            <span className="mt-1 block text-xs leading-relaxed text-zinc-500">
              {option.description}
            </span>
          </span>
        </label>
      ))}
    </div>
  );
}
