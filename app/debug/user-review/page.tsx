"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { RefreshCw } from "lucide-react";

import { UserReviewPanel } from "@/components/debug/UserReviewPanel";
import { SiteHeader } from "@/components/SiteHeader";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { buildUserReviewReport } from "@/lib/research/user-review-workflow";
import {
  getOrCreateParticipantId,
  readStudyParticipantRoster,
  setActiveStudyParticipant,
} from "@/lib/research/retention-observation";
import type { UserReviewReport } from "@/types/validation-ops";

export default function UserReviewDebugPage() {
  const [report, setReport] = useState<UserReviewReport | null>(null);
  const [participantId, setParticipantId] = useState(getOrCreateParticipantId());
  const roster = readStudyParticipantRoster();

  const refresh = () => {
    setReport(buildUserReviewReport(participantId));
  };

  useEffect(() => {
    refresh();
  }, [participantId]);

  return (
    <div className="min-h-screen bg-zinc-950">
      <div className="mx-auto max-w-5xl px-4 pb-20 sm:px-6">
        <SiteHeader />

        <header className="mt-2 flex items-start justify-between gap-4">
          <div>
            <p className="text-xs uppercase tracking-[0.2em] text-violet-300/80">Validation</p>
            <h1 className="mt-2 text-3xl font-semibold tracking-tight text-white">User review</h1>
            <p className="mt-2 max-w-2xl text-sm leading-relaxed text-zinc-400">
              Per-tester founder review — callbacks, revisits, trust, attachment, and willingness. Debug only.
            </p>
          </div>
          <Button type="button" variant="ghost" size="sm" onClick={refresh}>
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

        {!report ? (
          <Card className="mt-6">
            <CardContent className="py-12 text-center text-sm text-zinc-500">Loading…</CardContent>
          </Card>
        ) : (
          <div className="mt-6">
            <UserReviewPanel report={report} onRefresh={refresh} />
          </div>
        )}

        <div className="mt-10 flex flex-wrap gap-3 text-sm">
          <Link href="/debug/validation-ops" className="text-violet-300 hover:text-violet-200">
            Validation ops →
          </Link>
          <Link href="/debug/tester-feedback" className="text-zinc-500 hover:text-zinc-300">
            Tester feedback →
          </Link>
        </div>
      </div>
    </div>
  );
}
