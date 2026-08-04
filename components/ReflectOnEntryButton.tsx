"use client";

import { useState } from "react";

import { ProcessingStatus } from "@/components/InsightCardStatus";
import { Button } from "@/components/ui/button";
import { generateReflectionForEntry } from "@/lib/pending-reflection";
import type { JournalEntry } from "@/types/journal";

export function ReflectOnEntryButton({
  entryId,
  onComplete,
}: {
  entryId: string;
  onComplete: (entry: JournalEntry) => void;
}) {
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const handleReflect = async () => {
    setBusy(true);
    setError(null);
    try {
      const updated = await generateReflectionForEntry(entryId);
      onComplete(updated);
    } catch (reflectError) {
      setError(
        reflectError instanceof Error
          ? reflectError.message
          : "Could not look for patterns in this moment",
      );
    } finally {
      setBusy(false);
    }
  };

  if (busy) {
    return (
      <div className="space-y-3 px-1">
        <ProcessingStatus stage="analyzing" />
      </div>
    );
  }

  return (
    <div className="space-y-3 px-1">
      <Button type="button" variant="secondary" size="sm" onClick={() => void handleReflect()}>
        Look for patterns
      </Button>
      <p className="text-xs leading-relaxed text-zinc-600">
        Look for patterns when you are ready — nothing happens until you ask.
      </p>
      {error ? <p className="text-xs text-red-300/90">{error}</p> : null}
    </div>
  );
}
