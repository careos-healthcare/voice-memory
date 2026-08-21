"use client";

import { useEffect, useState } from "react";

import { ArchiveMovementCard } from "@/archived-components/_archived/archive/ArchiveMovementCard";
import { buildArchiveMovementFromArchive } from "@/lib/archive/archive-movement";
import { readLatestArchiveMovement } from "@/lib/metrics/archive-movement-events";
import type { ArchiveMovementUpdate } from "@/types/archive-movement";

interface LatestArchiveMovementCardProps {
  className?: string;
}

export function LatestArchiveMovementCard({ className = "" }: LatestArchiveMovementCardProps) {
  const [update, setUpdate] = useState<ArchiveMovementUpdate | null>(null);

  useEffect(() => {
    const stored = readLatestArchiveMovement();
    setUpdate(stored ?? buildArchiveMovementFromArchive());
  }, []);

  if (!update) return null;

  return <ArchiveMovementCard update={update} className={className} />;
}
