"use client";

import { useEffect, useState } from "react";

import { Button } from "@/components/ui/button";
import { saveTerritoryRename } from "@/lib/territories/territory-preferences";
import { trackTerritoryRenamed } from "@/lib/territories/territory-observation";

export function TerritoryRenameControl({
  territoryId,
  currentLabel,
  defaultLabel,
}: {
  territoryId: string;
  currentLabel: string;
  defaultLabel: string;
}) {
  const [editing, setEditing] = useState(false);
  const [draft, setDraft] = useState(currentLabel);

  useEffect(() => {
    setDraft(currentLabel);
  }, [currentLabel]);

  const save = () => {
    const trimmed = draft.trim();
    if (!trimmed || trimmed === defaultLabel) {
      saveTerritoryRename(territoryId, "");
    } else {
      saveTerritoryRename(territoryId, trimmed);
      trackTerritoryRenamed(territoryId, trimmed);
    }
    setEditing(false);
    window.dispatchEvent(new CustomEvent("voicememory:territory-preferences"));
  };

  if (!editing) {
    return (
      <Button
        type="button"
        variant="ghost"
        size="sm"
        className="text-zinc-600 hover:text-zinc-400"
        onClick={() => setEditing(true)}
      >
        Rename gently
      </Button>
    );
  }

  return (
    <div className="flex flex-wrap items-center gap-2">
      <input
        value={draft}
        onChange={(event) => setDraft(event.target.value)}
        className="rounded-lg border border-white/[0.08] bg-zinc-900/60 px-3 py-2 text-sm text-zinc-300"
        aria-label="Territory name"
      />
      <Button type="button" size="sm" variant="secondary" onClick={save}>
        Save
      </Button>
      <Button
        type="button"
        size="sm"
        variant="ghost"
        onClick={() => {
          setDraft(currentLabel);
          setEditing(false);
        }}
      >
        Cancel
      </Button>
    </div>
  );
}
