"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { Headphones, Download, Moon, RotateCcw, Trash2 } from "lucide-react";

import { ReflectionGoalSetting } from "@/components/settings/ReflectionGoalSetting";
import { SiteFooter } from "@/components/SiteFooter";
import { SiteHeader } from "@/components/SiteHeader";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import {
  deleteAllEntriesAndAudio,
  resetOnboardingState,
  resetProPreviewPlan,
  resetReminderPreferencesToDefault,
} from "@/lib/data-controls";
import {
  buildExportJsonBundle,
  downloadJsonFile,
  slugExportDate,
} from "@/lib/memory-export";
import { trackLaunchEvent, LAUNCH_EVENTS } from "@/lib/local-analytics";
import { isFullDetailEnabled, setFullDetailEnabled } from "@/lib/quiet-mode";
import { useListeningMode } from "@/lib/hooks/useListeningMode";
import {
  DATA_DELETION_SUMMARY,
  DATA_EXPORT_SUMMARY,
  LOCAL_FIRST_SUMMARY,
} from "@/lib/trust-copy";
import { getStoredEntryCount } from "@/lib/storage";

export default function SettingsPage() {
  const [entryCount, setEntryCount] = useState(0);
  const [message, setMessage] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [fullDetail, setFullDetail] = useState(false);
  const { listeningMode, setListeningMode } = useListeningMode();

  const refreshCount = () => {
    setEntryCount(getStoredEntryCount());
  };

  useEffect(() => {
    refreshCount();
    setFullDetail(isFullDetailEnabled());
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

  const handleDeleteAll = async () => {
    if (
      !window.confirm(
        "Delete ALL reflections and audio on this device? This cannot be undone.",
      )
    ) {
      return;
    }
    setBusy(true);
    try {
      const removed = await deleteAllEntriesAndAudio();
      refreshCount();
      showMessage(`Deleted ${removed} reflection${removed === 1 ? "" : "s"}.`);
    } finally {
      setBusy(false);
    }
  };

  const handleResetReminders = () => {
    resetReminderPreferencesToDefault();
    showMessage("Reminder preferences reset to defaults.");
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
            only this browser.
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
              <CardTitle className="text-base">Your data on this device</CardTitle>
            </CardHeader>
            <CardContent className="space-y-3 text-sm text-zinc-400">
              <p>{LOCAL_FIRST_SUMMARY}</p>
              <p>
                Stored reflections:{" "}
                <span className="font-medium text-white">{entryCount}</span>
              </p>
              <p className="text-xs">{DATA_EXPORT_SUMMARY}</p>
              <p className="text-xs">{DATA_DELETION_SUMMARY}</p>
              <div className="flex flex-wrap gap-2 pt-2">
                <Link href="/export" className="text-violet-300 hover:text-violet-200 text-sm">
                  More export options →
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
              <CardTitle className="text-base text-red-200">Delete all entries</CardTitle>
            </CardHeader>
            <CardContent>
              <p className="text-sm text-zinc-400">
                Permanently removes all reflections, transcripts, and audio from this device.
              </p>
              <Button
                type="button"
                variant="secondary"
                size="sm"
                className="mt-4 border-red-500/30 text-red-200 hover:bg-red-500/10"
                disabled={busy || entryCount === 0}
                onClick={() => void handleDeleteAll()}
              >
                <Trash2 className="h-4 w-4" />
                Delete all entries
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
                Clear reminder preferences
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
