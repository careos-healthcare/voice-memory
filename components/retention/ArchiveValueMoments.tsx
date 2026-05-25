"use client";

import { useEffect, useState } from "react";

import { pickArchiveValueMoment } from "@/lib/retention/archive-value-moments";
import { trackEarlyArchiveAttachment } from "@/lib/retention/first-week-observation";
import { assessArchiveAttachment } from "@/lib/retention/archive-attachment-signals";
import type { ArchiveValueMomentOffer } from "@/types/first-week-retention";

export function ArchiveValueMoments() {
  const [moment, setMoment] = useState<ArchiveValueMomentOffer | null>(null);

  useEffect(() => {
    const id = requestAnimationFrame(() => {
      const line = pickArchiveValueMoment();
      setMoment(line);
      if (line) {
        const level = assessArchiveAttachment().level;
        trackEarlyArchiveAttachment(level);
      }
    });
    return () => cancelAnimationFrame(id);
  }, []);

  if (!moment) return null;

  return (
    <p className="text-sm leading-relaxed text-zinc-500">{moment.text}</p>
  );
}
