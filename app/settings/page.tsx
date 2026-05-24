"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { Headphones, Download, Moon, RotateCcw, Trash2 } from "lucide-react";

import { ReflectionGoalSetting } from "@/components/settings/ReflectionGoalSetting";
import { PrivacyTrustPanel } from "@/components/trust/PrivacyTrustPanel";
import { SiteFooter } from "@/components/SiteFooter";
import { SiteHeader } from "@/components/SiteHeader";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import {
  resetOnboardingState,
  resetProPreviewPlan,
  resetReminderPreferencesToDefault,
  runFullLocalReset,
} from "@/lib/data-controls";
import {
  buildArchiveOwnershipReport,
  buildSettingsOwnershipLine,
} from "@/lib/archive/archive-ownership";
import {
  buildExportJsonBundle,
  downloadJsonFile,
  slugExportDate,
} from "@/lib/memory-export";
import { trackLaunchEvent, LAUNCH_EVENTS } from "@/lib/local-analytics";
import { isFullDetailEnabled, setFullDetailEnabled } from "@/lib/quiet-mode";
import { useListeningMode } from "@/lib/hooks/useListeningMode";
import {
  DATA_EXPORT_SUMMARY,
  DELETE_ALL_CONFIRM_PHRASE,
  DELETE_ALL_LOCAL_PROMPT,
} from "@/lib/trust-copy";
import { getAllEntries, getStoredEntryCount } from "@/lib/storage";

export default function SettingsPage() {
  const [entryCount, setEntryCount] = useState(0);
  const [message, setMessage] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [fullDetail, setFullDetail] = useState(false);
  const [ownershipLine, setOwnershipLine] = useState<string | null>(null);
  const { listeningMode, setListeningMode } = useListeningMode();

  const refreshCount = () => {
    setEntryCount(getStoredEntryCount());
  };

  useEffect(() => {
    refreshCount();
    setFullDetail(isFullDetailEnabled());
    void buildArchiveOwnershipReport(getAllEntries()).then((report) => {
      setOwnershipLine(buildSettingsOwnershipLine(report));
    });
  }, []);

  const showMessage = (text: string) => {
    setMessage(text);
    window.setTimeout(() => setMessage(null), 4000);
  };

  const handleExportAll = () => {
    const bundle = buildExportJsonBundle();
    downloadJsonFile(`voicememory-all-${slugExportDate()}.json`, bundle);
    trackLaunchEvent(LAUNCH_EVENTS.exportUsed);
    showMessage("Export downloaded.");
  };

  const handleDeleteAllLocal = async () => {
    if (!window.confirm(DELETE_ALL_LOCAL_PROMPT)) {
      return;
    }

    const typed = window.prompt(
      `Type ${DELETE_ALL_CONFIRM_PHRASE} to confirm deletion of all local data.`,
    );
    if (typed !== DELETE_ALL_CONFIRM_PHRASE) {
      showMessage("Deletion cancelled.");
      return;
    }

    setBusy(true);
    try {
      const removed = await runFullLocalReset();
      refreshCount();
      showMessage(
        removed > 0
          ? `Deleted ${removed} reflection${removed === 1 ? "" : "s"} and cleared local preferences.`
          : "All local VoiceMemory data cleared.",
      );
    } finally {
      setBusy(false);
    }
  };

  const handleResetReminders = () => {
    resetReminderPreferencesToDefault();
    showMessage("Reminder preferences reset — all reminders off by default.");
  };

  const handleResetOnboarding = () => {
    resetOnboardingState();
    showMessage("Onboarding reset — welcome tips will show again.");
  };

  const handleClearPro = () => {
    resetProPreviewPlan();
    showMessage("Pro preview cleared — plan set to Free.");
  };

  return (
    <div className="min-h-screen bg-zinc-950">
      <div className="mx-auto max-w-3xl px-4 pb-20 sm:px-6">
        <SiteHeader />

        <header className="mt-2">
          <p className="text-xs uppercase tracking-[0.2em] text-violet-300/80">Data & privacy</p>
          <h1 className="mt-2 text-3xl font-semibold tracking-tight text-white">Settings</h1>
          <p className="mt-2 text-sm leading-relaxed text-zinc-400">
            Manage data stored on this device. VoiceMemory is local-first — these actions affect
            only this browser unless you use encrypted backup.
          </p>
        </header>

        {message ? (
          <p className="mt-4 rounded-xl border border-emerald-500/20 bg-emerald-500/10 px-4 py-3 text-sm text-emerald-200">
            {message}
          </p>
        ) : null}

        <div className="mt-6 space-y-4">
          <Card>
            <CardHeader className="pb-2">
              <CardTitle className="text-base">Privacy & your data</CardTitle>
            </CardHeader>
            <CardContent className="space-y-4 text-sm text-zinc-400">
              <PrivacyTrustPanel compact />
              <p>
                Stored reflections:{" "}
                <span className="font-medium text-white">{entryCount}</span>
              </p>
              <p className="text-xs">{DATA_EXPORT_SUMMARY}</p>
              {ownershipLine ? (
                <p className="text-sm leading-relaxed text-zinc-500">{ownershipLine}</p>
              ) : null}
              <div className="flex flex-wrap gap-2 pt-1">
                <Link href="/account" className="text-violet-300 hover:text-violet-200 text-sm">
                  Account & sync →
                </Link>
                <Link href="/archive" className="text-violet-300 hover:text-violet-200 text-sm">
                  Archive permanence →
                </Link>
                <Link href="/export" className="text-violet-300 hover:text-violet-200 text-sm">
                  More export options →
                </Link>
                <Link href="/safety" className="text-violet-300 hover:text-violet-200 text-sm">
                  Emotional safety →
                </Link>
                <Link href="/privacy" className="text-zinc-500 hover:text-zinc-300 text-sm">
                  Privacy policy →
                </Link>
              </div>
              <Button
                type="button"
                variant="secondary"
                size="sm"
                className="mt-2"
                onClick={handleExportAll}
              >
                <Download className="h-4 w-4" />
                Export all (JSON)
              </Button>
            </CardContent>
          </Card>

          <Card className="border-red-500/20">
            <CardHeader className="pb-2">
              <CardTitle className="text-base text-red-200">Delete all local data</CardTitle>
            </CardHeader>
            <CardContent>
              <p className="text-sm text-zinc-400">
                Permanently removes reflections, transcripts, audio, bookmarks, goals,
                reminder preferences, and onboarding state from this device. Encrypted cloud
                backup (if enabled) is not removed — sign out on Account or contact us.
              </p>
              <Button
                type="button"
                variant="secondary"
                size="sm"
                className="mt-4 border-red-500/30 text-red-200 hover:bg-red-500/10"
                disabled={busy}
                onClick={() => void handleDeleteAllLocal()}
              >
                <Trash2 className="h-4 w-4" />
                Delete all local data
              </Button>
            </CardContent>
          </Card>

          <Card>
            <CardHeader className="pb-2">
              <CardTitle className="text-base">How you use VoiceMemory</CardTitle>
            </CardHeader>
            <CardContent className="space-y-6">
              <div className="space-y-3">
                <p className="text-sm font-medium text-zinc-300">Reflection goal</p>
                <p className="text-sm text-zinc-400">
                  Optional. A quiet intention for how often you might return — not a target
                  to hit and not a streak to keep.
                </p>
                <ReflectionGoalSetting />
              </div>

              <div className="space-y-3 border-t border-white/5 pt-6">
                <p className="text-sm font-medium text-zinc-300">Listening mode</p>
                <p className="text-sm text-zinc-400">
                  Save recordings without immediate reflection. Your transcript and audio
                  are kept — you can reflect later when it feels right.
                </p>
                <Button
                  type="button"
                  variant={listeningMode ? "default" : "secondary"}
                  size="sm"
                  onClick={() => {
                    const next = !listeningMode;
                    setListeningMode(next);
                    showMessage(next ? "Listening mode on." : "Listening mode off.");
                  }}
                >
                  <Headphones className="h-4 w-4" />
                  {listeningMode ? "Listening mode on" : "Enable listening mode"}
                </Button>
              </div>

              <div className="space-y-3 border-t border-white/5 pt-6">
                <p className="text-sm font-medium text-zinc-300">Full detail</p>
                <p className="text-sm text-zinc-400">
                  Off by default. Turn on only if you want fuller reads and more detail
                  on each page.
                </p>
                <Button
                  type="button"
                  variant={fullDetail ? "default" : "secondary"}
                  size="sm"
                  onClick={() => {
                    const next = !fullDetail;
                    setFullDetailEnabled(next);
                    setFullDetail(next);
                    showMessage(next ? "Full detail on." : "Back to quiet view.");
                  }}
                >
                  <Moon className="h-4 w-4" />
                  {fullDetail ? "Full detail on" : "Enable full detail"}
                </Button>
              </div>
            </CardContent>
          </Card>

          <Card>
            <CardHeader className="pb-2">
              <CardTitle className="text-base">Preferences</CardTitle>
            </CardHeader>
            <CardContent className="flex flex-col gap-3 sm:flex-row sm:flex-wrap">
              <Button type="button" variant="ghost" size="sm" onClick={handleResetReminders}>
                <RotateCcw className="h-4 w-4" />
                Reset reminders (all off)
              </Button>
              <Button type="button" variant="ghost" size="sm" onClick={handleResetOnboarding}>
                <RotateCcw className="h-4 w-4" />
                Reset onboarding
              </Button>
              <Button type="button" variant="ghost" size="sm" onClick={handleClearPro}>
                <RotateCcw className="h-4 w-4" />
                Clear Pro preview
              </Button>
            </CardContent>
          </Card>
        </div>

        <SiteFooter className="mt-12" />
      </div>
    </div>
  );
}
