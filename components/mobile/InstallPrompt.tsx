"use client";

import { useEffect, useState } from "react";

import { Button } from "@/components/ui/button";
import {
  trackInstallAccepted,
  trackInstallPromptDismissed,
  trackInstallPromptShown,
} from "@/lib/behavior/observation";
import { isPWA } from "@/lib/mobile/platform";

const DISMISS_KEY = "voicememory_pwa_install_dismissed_until";
const DISMISS_DAYS = 14;

interface BeforeInstallPromptEvent extends Event {
  prompt: () => Promise<void>;
  userChoice: Promise<{ outcome: "accepted" | "dismissed" }>;
}

function dismissedRecently(): boolean {
  try {
    const raw = localStorage.getItem(DISMISS_KEY);
    if (!raw) return false;
    return Date.now() < Number(raw);
  } catch {
    return false;
  }
}

function dismissForDays(days: number): void {
  localStorage.setItem(DISMISS_KEY, String(Date.now() + days * 24 * 60 * 60 * 1000));
}

/** Single quiet install affordance — no nag loops. */
export function InstallPrompt() {
  const [deferred, setDeferred] = useState<BeforeInstallPromptEvent | null>(null);
  const [visible, setVisible] = useState(false);

  useEffect(() => {
    if (isPWA() || dismissedRecently()) return;

    const onBip = (event: Event) => {
      event.preventDefault();
      setDeferred(event as BeforeInstallPromptEvent);
      setVisible(true);
      trackInstallPromptShown();
    };

    window.addEventListener("beforeinstallprompt", onBip);
    return () => window.removeEventListener("beforeinstallprompt", onBip);
  }, []);

  if (!visible || !deferred) return null;

  const handleInstall = async () => {
    await deferred.prompt();
    const choice = await deferred.userChoice;
    if (choice.outcome === "accepted") {
      trackInstallAccepted();
    }
    setVisible(false);
    setDeferred(null);
  };

  const handleDismiss = () => {
    dismissForDays(DISMISS_DAYS);
    trackInstallPromptDismissed();
    setVisible(false);
    setDeferred(null);
  };

  return (
    <div
      role="status"
      className="fixed inset-x-4 bottom-[max(1rem,env(safe-area-inset-bottom))] z-40 mx-auto max-w-md rounded-2xl border border-white/10 bg-zinc-900/95 px-4 py-4 shadow-xl backdrop-blur-sm"
    >
      <p className="text-sm text-zinc-300">Add VoiceMemory to your home screen</p>
      <p className="mt-1 text-xs leading-relaxed text-zinc-600">
        Opens like an app — still private and on your device.
      </p>
      <div className="mt-3 flex flex-wrap gap-2">
        <Button type="button" size="sm" onClick={() => void handleInstall()}>
          Install
        </Button>
        <Button type="button" size="sm" variant="ghost" onClick={handleDismiss}>
          Not now
        </Button>
      </div>
    </div>
  );
}
