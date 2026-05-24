"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { RefreshCw } from "lucide-react";

import { PilotReviewPanel } from "@/components/debug/PilotReviewPanel";
import { SiteHeader } from "@/components/SiteHeader";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { buildPilotReviewReport } from "@/lib/debug/pilot-review";
import {
  readStudyParticipantRoster,
  setActiveStudyParticipant,
  getOrCreateParticipantId,
} from "@/lib/research/retention-observation";
import {
  setPilotAccessStatus,
  savePilotFounderNote,
} from "@/lib/pilot/pilot-access";
import { savePilotFounderLabel } from "@/lib/pilot/pilot-interest";
import type { PilotReviewReport } from "@/types/pilot-system";
import type { PilotAccessStatus, PilotFounderLabel } from "@/types/pilot-system";

export default function PilotReviewDebugPage() {
  const [report, setReport] = useState<PilotReviewReport | null>(null);
  const [participantId, setParticipantId] = useState(getOrCreateParticipantId());
  const roster = readStudyParticipantRoster();

  const refresh = async () => {
    setReport(await buildPilotReviewReport());
  };

  useEffect(() => {
    void refresh();
  }, [participantId]);

  const setStatus = (status: PilotAccessStatus) => {
    setPilotAccessStatus({ participantId, status });
    void refresh();
  };

  const setLabel = (label: PilotFounderLabel) => {
    const note = window.prompt("Optional note:") ?? undefined;
    savePilotFounderLabel({ participantId, label, note: note || undefined });
    void refresh();
  };

  const addNote = () => {
    const text = window.prompt("Founder pilot note:");
    if (!text?.trim()) return;
    savePilotFounderNote({ participantId, text });
    void refresh();
  };

  return (
    <div className="min-h-screen bg-zinc-950">
      <div className="mx-auto max-w-5xl px-4 pb-20 sm:px-6">
        <SiteHeader />

        <header className="mt-2 flex items-start justify-between gap-4">
          <div>
            <p className="text-xs uppercase tracking-[0.2em] text-violet-300/80">Pilot</p>
            <h1 className="mt-2 text-3xl font-semibold tracking-tight text-white">Pilot review</h1>
            <p className="mt-2 max-w-2xl text-sm leading-relaxed text-zinc-400">
              Founder-led paid pilot review — attachment, trust, access roster. Debug only.
            </p>
          </div>
          <Button type="button" variant="ghost" size="sm" onClick={() => void refresh()}>
            <RefreshCw className="h-4 w-4" />
            Refresh
          </Button>
        </header>

        <div className="mt-4 flex flex-wrap gap-2">
          {roster.map((participant) => (
            <Button
              key={participant.id}
              type="button"
              variant={participant.id === participantId ? "secondary" : "ghost"}
              size="sm"
              onClick={() => {
                setActiveStudyParticipant(participant.id);
                setParticipantId(participant.id);
              }}
            >
              {participant.label ?? participant.id.slice(0, 8)}
            </Button>
          ))}
        </div>

        <div className="mt-4 flex flex-wrap gap-2">
          {(["approved", "invited", "observing", "declined"] as const).map((status) => (
            <Button key={status} type="button" variant="ghost" size="sm" onClick={() => setStatus(status)}>
              {status}
            </Button>
          ))}
          {(["highly_attached", "trust_sensitive", "likely_early_supporter", "not_ready"] as const).map(
            (label) => (
              <Button key={label} type="button" variant="ghost" size="sm" onClick={() => setLabel(label)}>
                {label.replace(/_/g, " ")}
              </Button>
            ),
          )}
          <Button type="button" variant="ghost" size="sm" onClick={addNote}>
            Add note
          </Button>
        </div>

        {!report ? (
          <Card className="mt-6">
            <CardContent className="py-12 text-center text-sm text-zinc-500">Loading…</CardContent>
          </Card>
        ) : (
          <div className="mt-6">
            <PilotReviewPanel report={report} />
          </div>
        )}

        <div className="mt-10 flex flex-wrap gap-3 text-sm">
          <Link href="/debug/pilot-readiness" className="text-violet-300 hover:text-violet-200">
            Pilot readiness →
          </Link>
          <Link href="/pilot" className="text-zinc-500 hover:text-zinc-300">
            Pilot page →
          </Link>
        </div>
      </div>
    </div>
  );
}
