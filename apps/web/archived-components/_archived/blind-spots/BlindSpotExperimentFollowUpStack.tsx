"use client";

import { useCallback, useEffect, useState } from "react";

import { BlindSpotExperimentFollowUpPrompt } from "@/archived-components/_archived/blind-spots/BlindSpotExperimentFollowUpPrompt";
import { getDueExperimentFollowUps } from "@/lib/blind-spots/blind-spot-experiment-commitment";
import type { BlindSpotExperimentCommitment } from "@/types/blind-spot-experiment-loop";

interface BlindSpotExperimentFollowUpStackProps {
  className?: string;
}

export function BlindSpotExperimentFollowUpStack({
  className = "",
}: BlindSpotExperimentFollowUpStackProps) {
  const [due, setDue] = useState<BlindSpotExperimentCommitment[]>([]);

  const refresh = useCallback(() => {
    setDue(getDueExperimentFollowUps());
  }, []);

  useEffect(() => {
    refresh();
  }, [refresh]);

  if (due.length === 0) return null;

  return (
    <div className={`space-y-3 ${className}`.trim()}>
      {due.map((commitment) => (
        <BlindSpotExperimentFollowUpPrompt
          key={commitment.commitmentId}
          commitment={commitment}
          onAnswered={refresh}
        />
      ))}
    </div>
  );
}
