"use client";

import { useCallback, useMemo, useState } from "react";

import { ArchiveAsProductValidationPanel } from "@/archived-components/_archived/internal/ArchiveAsProductValidationPanel";
import { ArchiveBeliefCenterPanel } from "@/archived-components/_archived/internal/ArchiveBeliefCenterPanel";
import { DesignConsistencyAuditPanel } from "@/archived-components/_archived/internal/DesignConsistencyAuditPanel";
import type { DesignConsistencyFileReport } from "@/lib/internal/design-consistency-file-audit";
import { ArchiveUnderstandingPanel } from "@/archived-components/_archived/internal/ArchiveUnderstandingPanel";
import { FounderEvolvingValidationPanel } from "@/archived-components/_archived/internal/FounderEvolvingValidationPanel";
import { FounderTestParticipantCard } from "@/archived-components/_archived/internal/FounderTestParticipantCard";
import { FounderTestReportPanel } from "@/archived-components/_archived/internal/FounderTestReportPanel";
import { Button } from "@/archived-components/_archived/ui/button";
import { Card, CardContent } from "@/archived-components/_archived/ui/card";
import {
  FOUNDER_EVOLVING_INTERVIEW_QUESTIONS,
  FOUNDER_TEST_CORE_QUESTION,
  FOUNDER_TEST_INTERVIEW_QUESTIONS,
} from "@/lib/founder-test/founder-test-checklist";
import { readFounderTestDeviceHints } from "@/lib/founder-test/founder-test-device-hints";
import { buildArchiveAsProductValidationReport } from "@/lib/founder-test/archive-as-product-metrics";
import { ARCHIVE_AS_PRODUCT_INTERVIEW_QUESTIONS } from "@/lib/founder-test/archive-as-product-validation";
import { buildFounderTestReport } from "@/lib/founder-test/founder-test-report";
import {
  createFounderTestParticipant,
  markChecklistItem,
  readFounderTestRecords,
  updateFounderTestParticipant,
  updateFounderTestSession,
} from "@/lib/founder-test/founder-test-storage";
import type { FounderTestRecord } from "@/types/founder-test";

export function FounderTestPanel({
  designReport,
}: {
  designReport?: DesignConsistencyFileReport;
}) {
  const [records, setRecords] = useState<FounderTestRecord[]>(() => readFounderTestRecords());
  const [newLabel, setNewLabel] = useState("");

  const refresh = useCallback(() => {
    setRecords(readFounderTestRecords());
  }, []);

  const report = useMemo(() => buildFounderTestReport(records), [records]);
  const archiveAsProductReport = useMemo(
    () => buildArchiveAsProductValidationReport(records),
    [records],
  );

  function handleAddParticipant() {
    createFounderTestParticipant(newLabel);
    setNewLabel("");
    refresh();
  }

  function handleSyncDevice(participantId: string) {
    const hints = readFounderTestDeviceHints();
    updateFounderTestSession(participantId, hints);
    refresh();
  }

  return (
    <div className="space-y-10">
      <Card className="border-violet-500/20 bg-violet-950/10">
        <CardContent className="space-y-4 pt-6">
          <p className="text-sm font-medium text-violet-100">Core question</p>
          <p className="text-sm leading-relaxed text-zinc-300">{FOUNDER_TEST_CORE_QUESTION}</p>
          <p className="text-xs text-zinc-500">
            Local checklist only — no server. Sync device signals pulls reflection count and open
            events from this browser.
          </p>
        </CardContent>
      </Card>

      <ArchiveAsProductValidationPanel report={archiveAsProductReport} />

      <ArchiveUnderstandingPanel />

      <ArchiveBeliefCenterPanel />

      {designReport ? <DesignConsistencyAuditPanel report={designReport} /> : null}

      <FounderEvolvingValidationPanel report={report.evolvingValidation} />

      <FounderTestReportPanel report={report} />

      <Card className="border-emerald-500/15 bg-emerald-950/10">
        <CardContent className="space-y-3 pt-6">
          <p className="text-sm font-medium text-emerald-100">
            Archive-as-product — ask these four (roadmap gate)
          </p>
          <ol className="list-decimal space-y-2 pl-5 text-sm text-zinc-400">
            {ARCHIVE_AS_PRODUCT_INTERVIEW_QUESTIONS.map((q) => (
              <li key={q}>{q}</li>
            ))}
          </ol>
        </CardContent>
      </Card>

      <Card className="border-violet-500/15 bg-violet-950/10">
        <CardContent className="space-y-3 pt-6">
          <p className="text-sm font-medium text-violet-100">
            After first working theory — ask these four
          </p>
          <ol className="list-decimal space-y-2 pl-5 text-sm text-zinc-400">
            {FOUNDER_EVOLVING_INTERVIEW_QUESTIONS.map((q) => (
              <li key={q}>{q}</li>
            ))}
          </ol>
        </CardContent>
      </Card>

      <Card className="border-white/10 bg-zinc-900/50">
        <CardContent className="space-y-4 pt-6">
          <p className="text-sm font-medium text-zinc-300">Interview questions</p>
          <ol className="list-decimal space-y-2 pl-5 text-sm text-zinc-400">
            {FOUNDER_TEST_INTERVIEW_QUESTIONS.map((q) => (
              <li key={q}>{q}</li>
            ))}
          </ol>
        </CardContent>
      </Card>

      <div className="flex flex-wrap items-end gap-3">
        <label className="flex-1 min-w-[200px] space-y-1 text-sm">
          <span className="text-zinc-400">Add participant</span>
          <input
            type="text"
            value={newLabel}
            onChange={(e) => setNewLabel(e.target.value)}
            placeholder="e.g. Tester A — May 25"
            className="w-full rounded-lg border border-white/10 bg-zinc-900 px-3 py-2 text-sm text-zinc-200"
          />
        </label>
        <Button type="button" onClick={handleAddParticipant}>
          Add participant
        </Button>
      </div>

      {records.length === 0 ? (
        <Card>
          <CardContent className="py-12 text-center text-sm text-zinc-500">
            No participants yet. Add someone before your next user study session.
          </CardContent>
        </Card>
      ) : (
        <div className="space-y-6">
          {records.map((record) => (
            <FounderTestParticipantCard
              key={record.participant.id}
              record={record}
              onSessionChange={(id, patch) => {
                updateFounderTestSession(id, patch);
                refresh();
              }}
              onNotesChange={(id, notes) => {
                updateFounderTestParticipant(id, { notes: notes || undefined });
                refresh();
              }}
              onChecklistToggle={(id, itemId, completed) => {
                markChecklistItem(id, itemId, completed);
                refresh();
              }}
              onSyncDevice={handleSyncDevice}
            />
          ))}
        </div>
      )}
    </div>
  );
}
