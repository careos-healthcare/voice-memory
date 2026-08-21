"use client";

import { ResurfacingNotes } from "@/archived-components/_archived/patterns/MemoryNote";
import { RecordReturnAnchor } from "@/archived-components/_archived/recording/RecordReturnAnchor";
import { buildRecordReturnFromNote } from "@/lib/reflection/record-return";
import { startRecordReturnFlow } from "@/lib/reflection/start-record-return";
import type { MemoryNote } from "@/types/memory-note";

/** Single tuned callback — primary action opens recorder immediately. */
export function PrimaryCallbackNote({
  note,
  onRecordAgain,
}: {
  note: MemoryNote | null;
  onRecordAgain?: () => void;
}) {
  if (!note) return null;

  const context = buildRecordReturnFromNote(note, "primary_callback");

  return (
    <div className="space-y-5">
      <ResurfacingNotes notes={[note]} max={1} />
      {onRecordAgain ? (
        <div className="flex justify-center">
          <RecordReturnAnchor
            context={context}
            onRecordAgain={() => {
              startRecordReturnFlow(context);
              onRecordAgain();
            }}
          />
        </div>
      ) : null}
    </div>
  );
}
