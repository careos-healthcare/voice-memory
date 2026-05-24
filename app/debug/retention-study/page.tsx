"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { ClipboardList, Download, RefreshCw } from "lucide-react";

import { SiteHeader } from "@/components/SiteHeader";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import {
  buildAnonymizedStudyExport,
  buildRetentionObservationSnapshot,
  clearManualStudyNotes,
  downloadStudyExportJson,
  getOrCreateParticipantId,
  getStudyAnchorDay,
  readManualStudyNotes,
  resetStudyAnchorDay,
  saveManualStudyNote,
} from "@/lib/research/retention-observation";
import { formatEntryDate } from "@/lib/utils";
import type { RetentionObservationSnapshot, WouldPayAnswer } from "@/types/retention-observation";

function StatCard({ label, value, hint }: { label: string; value: string; hint?: string }) {
  return (
    <Card>
      <CardHeader className="pb-1">
        <CardTitle className="text-xs font-normal uppercase tracking-wider text-zinc-500">
          {label}
        </CardTitle>
      </CardHeader>
      <CardContent>
        <p className="text-2xl font-semibold tabular-nums text-white">{value}</p>
        {hint ? <p className="mt-1 text-xs text-zinc-600">{hint}</p> : null}
      </CardContent>
    </Card>
  );
}

export default function RetentionStudyDebugPage() {
  const [snapshot, setSnapshot] = useState<RetentionObservationSnapshot | null>(null);
  const [busy, setBusy] = useState(false);
  const [message, setMessage] = useState<string | null>(null);

  const [rememberedSentence48h, setRememberedSentence48h] = useState("");
  const [userQuote, setUserQuote] = useState("");
  const [payReason, setPayReason] = useState("");
  const [wouldPay, setWouldPay] = useState<WouldPayAnswer | "">("");
  const [feltRemembered, setFeltRemembered] = useState<boolean | null>(null);
  const [feltGeneric, setFeltGeneric] = useState<boolean | null>(null);

  const refresh = async () => {
    setSnapshot(await buildRetentionObservationSnapshot());
  };

  useEffect(() => {
    void refresh();
  }, []);

  const showMessage = (text: string) => {
    setMessage(text);
    window.setTimeout(() => setMessage(null), 4000);
  };

  const handleSaveNote = () => {
    setBusy(true);
    try {
      saveManualStudyNote({
        rememberedSentence48h,
        userQuote,
        payReason,
        wouldPay: wouldPay || undefined,
        feltRemembered: feltRemembered ?? undefined,
        feltGeneric: feltGeneric ?? undefined,
      });
      setRememberedSentence48h("");
      setUserQuote("");
      setPayReason("");
      setWouldPay("");
      setFeltRemembered(null);
      setFeltGeneric(null);
      showMessage("Observation saved locally.");
      void refresh();
    } catch (error) {
      showMessage(error instanceof Error ? error.message : "Could not save.");
    } finally {
      setBusy(false);
    }
  };

  const handleExport = async () => {
    setBusy(true);
    try {
      const payload = await buildAnonymizedStudyExport();
      downloadStudyExportJson(payload);
      showMessage("Study JSON exported.");
    } finally {
      setBusy(false);
    }
  };

  const manualNotes = readManualStudyNotes();

  return (
    <div className="min-h-screen bg-zinc-950">
      <div className="mx-auto max-w-5xl px-4 pb-20 sm:px-6">
        <SiteHeader />

        <header className="mt-2 flex items-start justify-between gap-4">
          <div>
            <p className="text-xs uppercase tracking-[0.2em] text-violet-300/80">
              Research — debug only
            </p>
            <h1 className="mt-2 text-3xl font-semibold tracking-tight text-white">
              Retention study
            </h1>
            <p className="mt-2 max-w-2xl text-sm leading-relaxed text-zinc-400">
              Local observation for 10–20 users over 30–60 days. Nothing leaves this device unless
              you export JSON.
            </p>
          </div>
          <div className="flex shrink-0 gap-2">
            <Button type="button" variant="ghost" size="sm" onClick={() => void refresh()}>
              <RefreshCw className="h-4 w-4" />
              Refresh
            </Button>
            <Button type="button" variant="secondary" size="sm" disabled={busy} onClick={() => void handleExport()}>
              <Download className="h-4 w-4" />
              Export JSON
            </Button>
          </div>
        </header>

        {!snapshot ? (
          <Card className="mt-6">
            <CardContent className="py-12 text-center text-sm text-zinc-500">Loading…</CardContent>
          </Card>
        ) : (
          <div className="mt-6 space-y-6">
            <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
              <StatCard
                label="Participant"
                value={getOrCreateParticipantId()}
                hint="Opaque local id"
              />
              <StatCard
                label="Study day"
                value={String(snapshot.participant.studyDayCount)}
                hint={`Anchor ${getStudyAnchorDay()}`}
              />
              <StatCard
                label="Return days"
                value={String(snapshot.participant.returnDayCount)}
              />
              <StatCard
                label="Reflections"
                value={String(snapshot.participant.reflectionCount)}
              />
            </div>

            <Card>
              <CardHeader className="pb-2">
                <CardTitle className="text-sm font-normal text-zinc-200">
                  7 / 30 / 60 day indicators
                </CardTitle>
              </CardHeader>
              <CardContent>
                <ul className="space-y-3">
                  {snapshot.retentionWindows.map((window) => (
                    <li
                      key={window.windowDays}
                      className="rounded-xl bg-white/[0.03] px-3 py-3 text-sm text-zinc-400"
                    >
                      <p className="font-medium text-zinc-200">{window.windowDays} days</p>
                      <p className="mt-1 text-xs text-zinc-500">
                        {window.eligible ? "Window complete" : "Still collecting"} ·{" "}
                        {window.activeReturnDays} active return day
                        {window.activeReturnDays === 1 ? "" : "s"} · returned after first use:{" "}
                        {window.returnedAfterFirstUse ? "yes" : "no"}
                      </p>
                      <p className="mt-1 text-xs text-zinc-600">
                        Revisits {window.oldEntryRevisits} · follow-ups {window.followupsCompleted}/
                        {window.followupsStarted} · bookmarks {window.bookmarks} · copies{" "}
                        {window.copiedMoments}
                      </p>
                    </li>
                  ))}
                </ul>
              </CardContent>
            </Card>

            <Card>
              <CardHeader className="pb-2">
                <CardTitle className="text-sm font-normal text-zinc-200">Revisit funnel</CardTitle>
              </CardHeader>
              <CardContent>
                <ul className="space-y-2">
                  {snapshot.revisitFunnel.map((step) => (
                    <li
                      key={step.step}
                      className="flex items-center justify-between rounded-lg bg-white/[0.03] px-3 py-2 text-sm"
                    >
                      <span className="text-zinc-400">{step.step}</span>
                      <span className="tabular-nums text-zinc-200">{step.count}</span>
                    </li>
                  ))}
                </ul>
              </CardContent>
            </Card>

            <Card>
              <CardHeader className="pb-2">
                <CardTitle className="text-sm font-normal text-zinc-200">
                  Archive protection behavior
                </CardTitle>
              </CardHeader>
              <CardContent className="space-y-2 text-sm text-zinc-400">
                <p>Export used: {snapshot.archiveProtection.exportUsed ? "yes" : "no"}</p>
                <p>
                  Encrypted backup:{" "}
                  {snapshot.archiveProtection.encryptedBackupConfigured ? "yes" : "no"}
                </p>
                <p>
                  Local export: {snapshot.archiveProtection.localExportUsed ? "yes" : "no"}
                </p>
                <p>
                  Backup configured: {snapshot.archiveProtection.backupConfigured ? "yes" : "no"}
                </p>
                <p className="text-xs text-zinc-600">
                  Export events: {snapshot.archiveProtection.exportCount}
                </p>
              </CardContent>
            </Card>

            <Card>
              <CardHeader className="pb-2">
                <CardTitle className="flex items-center gap-2 text-sm font-normal text-zinc-200">
                  <ClipboardList className="h-4 w-4 text-violet-300" />
                  Manual observation
                </CardTitle>
              </CardHeader>
              <CardContent className="space-y-4">
                <label className="block space-y-1 text-sm text-zinc-400">
                  Remembered sentence (after 48h)
                  <textarea
                    value={rememberedSentence48h}
                    onChange={(event) => setRememberedSentence48h(event.target.value)}
                    rows={2}
                    className="w-full rounded-lg border border-white/[0.08] bg-zinc-950 px-3 py-2 text-sm text-zinc-200 outline-none ring-violet-500/30 focus:ring-2"
                  />
                </label>
                <label className="block space-y-1 text-sm text-zinc-400">
                  User quote
                  <textarea
                    value={userQuote}
                    onChange={(event) => setUserQuote(event.target.value)}
                    rows={2}
                    className="w-full rounded-lg border border-white/[0.08] bg-zinc-950 px-3 py-2 text-sm text-zinc-200 outline-none ring-violet-500/30 focus:ring-2"
                  />
                </label>
                <div className="flex flex-wrap gap-4 text-sm text-zinc-400">
                  <label className="flex items-center gap-2">
                    <input
                      type="checkbox"
                      checked={feltRemembered === true}
                      onChange={(event) =>
                        setFeltRemembered(event.target.checked ? true : null)
                      }
                    />
                    Felt remembered
                  </label>
                  <label className="flex items-center gap-2">
                    <input
                      type="checkbox"
                      checked={feltGeneric === true}
                      onChange={(event) => setFeltGeneric(event.target.checked ? true : null)}
                    />
                    Felt generic
                  </label>
                </div>
                <label className="block space-y-1 text-sm text-zinc-400">
                  Would pay?
                  <select
                    value={wouldPay}
                    onChange={(event) => setWouldPay(event.target.value as WouldPayAnswer | "")}
                    className="w-full rounded-lg border border-white/[0.08] bg-zinc-950 px-3 py-2 text-sm text-zinc-200 outline-none ring-violet-500/30 focus:ring-2"
                  >
                    <option value="">—</option>
                    <option value="yes">Yes</option>
                    <option value="maybe">Maybe</option>
                    <option value="no">No</option>
                  </select>
                </label>
                <label className="block space-y-1 text-sm text-zinc-400">
                  Reason
                  <textarea
                    value={payReason}
                    onChange={(event) => setPayReason(event.target.value)}
                    rows={2}
                    className="w-full rounded-lg border border-white/[0.08] bg-zinc-950 px-3 py-2 text-sm text-zinc-200 outline-none ring-violet-500/30 focus:ring-2"
                  />
                </label>
                <Button type="button" size="sm" disabled={busy} onClick={handleSaveNote}>
                  Save observation
                </Button>
              </CardContent>
            </Card>

            <Card>
              <CardHeader className="pb-2">
                <CardTitle className="text-sm font-normal text-zinc-200">
                  Emotional residue notes ({manualNotes.length})
                </CardTitle>
              </CardHeader>
              <CardContent>
                {manualNotes.length === 0 ? (
                  <p className="text-sm text-zinc-500">No manual notes yet.</p>
                ) : (
                  <ul className="space-y-3">
                    {manualNotes.map((note) => (
                      <li
                        key={note.id}
                        className="rounded-xl bg-white/[0.03] px-3 py-3 text-sm text-zinc-400"
                      >
                        <p className="text-xs text-zinc-600">{formatEntryDate(note.createdAt)}</p>
                        {note.rememberedSentence48h ? (
                          <p className="mt-1">
                            Remembered: {note.rememberedSentence48h}
                          </p>
                        ) : null}
                        {note.userQuote ? <p className="mt-1">Quote: {note.userQuote}</p> : null}
                        {note.feltRemembered ? (
                          <p className="mt-1 text-emerald-300/80">Felt remembered</p>
                        ) : null}
                        {note.feltGeneric ? (
                          <p className="mt-1 text-amber-200/80">Felt generic</p>
                        ) : null}
                        {note.wouldPay ? (
                          <p className="mt-1">
                            Would pay: {note.wouldPay}
                            {note.payReason ? ` — ${note.payReason}` : ""}
                          </p>
                        ) : null}
                      </li>
                    ))}
                  </ul>
                )}
                <div className="mt-4 flex flex-wrap gap-2">
                  <Button
                    type="button"
                    size="sm"
                    variant="ghost"
                    disabled={busy}
                    onClick={() => {
                      resetStudyAnchorDay();
                      showMessage(`Study anchor reset to ${getStudyAnchorDay()}.`);
                      void refresh();
                    }}
                  >
                    Reset study anchor to today
                  </Button>
                  <Button
                    type="button"
                    size="sm"
                    variant="ghost"
                    disabled={busy || manualNotes.length === 0}
                    onClick={() => {
                      clearManualStudyNotes();
                      showMessage("Manual notes cleared.");
                      void refresh();
                    }}
                  >
                    Clear manual notes
                  </Button>
                </div>
              </CardContent>
            </Card>

            {message ? <p className="text-sm text-zinc-400">{message}</p> : null}

            <div className="flex flex-wrap gap-3 text-sm">
              <Link href="/debug/retention-loops" className="text-violet-300 hover:text-violet-200">
                Retention loops →
              </Link>
              <Link href="/debug/retention" className="text-violet-300 hover:text-violet-200">
                Launch validation →
              </Link>
              <Link href="/debug/suppression" className="text-zinc-500 hover:text-zinc-300">
                Suppression review →
              </Link>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
