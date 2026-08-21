"use client";

import { Download } from "lucide-react";

import { Button } from "@/archived-components/_archived/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/archived-components/_archived/ui/card";
import {
  completeFollowUpReminder,
  downloadUserReviewJson,
  saveFollowUpReminder,
  saveFounderUserNote,
} from "@/lib/research/user-review-workflow";
import { saveWillingnessFounderLabel } from "@/lib/research/willingness-signals";
import type { UserReviewReport } from "@/types/validation-ops";
import type { FounderWillingnessLabel } from "@/types/validation-ops";

function SectionBlock({ section }: { section: UserReviewReport["sections"][keyof UserReviewReport["sections"]] }) {
  return (
    <Card>
      <CardHeader className="pb-2">
        <CardTitle className="text-sm font-normal text-zinc-200">{section.title}</CardTitle>
      </CardHeader>
      <CardContent>
        {section.rows.length === 0 ? (
          <p className="text-sm text-zinc-500">{section.empty}</p>
        ) : (
          <ul className="space-y-2 text-sm text-zinc-400">
            {section.rows.map((row) => (
              <li key={row.id}>
                {row.label}
                {row.detail ? <span className="text-zinc-600"> — {row.detail}</span> : null}
              </li>
            ))}
          </ul>
        )}
      </CardContent>
    </Card>
  );
}

export function UserReviewPanel({
  report,
  onRefresh,
}: {
  report: UserReviewReport;
  onRefresh: () => void;
}) {
  const participantId = report.participant.id;

  const handleSaveNote = () => {
    const text = window.prompt("Founder note for this tester:");
    if (!text?.trim()) return;
    saveFounderUserNote(participantId, text);
    onRefresh();
  };

  const handleSaveReminder = () => {
    const dueDay = window.prompt("Follow-up due date (YYYY-MM-DD):");
    if (!dueDay) return;
    const note = window.prompt("Follow-up reminder:");
    if (!note?.trim()) return;
    saveFollowUpReminder({ participantId, dueDay, note });
    onRefresh();
  };

  const handleWtpLabel = (label: FounderWillingnessLabel) => {
    const note = window.prompt(`Label: ${label.replace("_", " ")} — optional note:`) ?? undefined;
    saveWillingnessFounderLabel({ participantId, label, note: note || undefined });
    onRefresh();
  };

  return (
    <div className="space-y-6">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div>
          <p className="text-sm text-zinc-200">{report.participant.label ?? report.participant.id}</p>
          <p className="text-xs text-zinc-600">Anchor {report.participant.anchorDay.slice(0, 10)}</p>
        </div>
        <div className="flex flex-wrap gap-2">
          <Button type="button" variant="secondary" size="sm" onClick={() => downloadUserReviewJson(participantId)}>
            <Download className="h-4 w-4" />
            Anonymized export
          </Button>
          <Button type="button" variant="ghost" size="sm" onClick={handleSaveNote}>
            Add note
          </Button>
          <Button type="button" variant="ghost" size="sm" onClick={handleSaveReminder}>
            Add reminder
          </Button>
        </div>
      </div>

      <div className="flex flex-wrap gap-2">
        <Button type="button" variant="ghost" size="sm" onClick={() => handleWtpLabel("would_pay")}>
          Would pay
        </Button>
        <Button type="button" variant="ghost" size="sm" onClick={() => handleWtpLabel("maybe")}>
          Maybe
        </Button>
        <Button type="button" variant="ghost" size="sm" onClick={() => handleWtpLabel("unlikely")}>
          Unlikely
        </Button>
      </div>

      {report.founderNotes.length > 0 ? (
        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-normal text-zinc-200">Founder notes</CardTitle>
          </CardHeader>
          <CardContent>
            <ul className="space-y-2 text-sm text-zinc-400">
              {report.founderNotes.map((note) => (
                <li key={note.id}>
                  {note.text}
                  <span className="text-zinc-600"> · {note.createdAt.slice(0, 10)}</span>
                </li>
              ))}
            </ul>
          </CardContent>
        </Card>
      ) : null}

      {report.followUpReminders.length > 0 ? (
        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-normal text-zinc-200">Follow-up reminders</CardTitle>
          </CardHeader>
          <CardContent>
            <ul className="space-y-2 text-sm text-zinc-400">
              {report.followUpReminders.map((reminder) => (
                <li key={reminder.id} className="flex flex-wrap items-center gap-2">
                  <span>
                    {reminder.dueDay}: {reminder.note}
                    {reminder.completed ? " (done)" : ""}
                  </span>
                  {!reminder.completed ? (
                    <Button
                      type="button"
                      variant="ghost"
                      size="sm"
                      onClick={() => {
                        completeFollowUpReminder(reminder.id);
                        onRefresh();
                      }}
                    >
                      Done
                    </Button>
                  ) : null}
                </li>
              ))}
            </ul>
          </CardContent>
        </Card>
      ) : null}

      <div className="grid gap-4 lg:grid-cols-2">
        <SectionBlock section={report.sections.strongestCallbacks} />
        <SectionBlock section={report.sections.ignoredCallbacks} />
        <SectionBlock section={report.sections.revisitBehavior} />
        <SectionBlock section={report.sections.reflectionContinuation} />
        <SectionBlock section={report.sections.trustIncidents} />
        <SectionBlock section={report.sections.emotionalLegitimacy} />
        <SectionBlock section={report.sections.attachmentSignals} />
        <SectionBlock section={report.sections.willingnessSignals} />
        <SectionBlock section={report.sections.feltRemembered} />
        <SectionBlock section={report.sections.feltGeneric} />
      </div>
    </div>
  );
}
