import { readLocalEvents } from "@/lib/local-analytics";
import { getMemoryEligibleEntries } from "@/lib/storage";
import { recordFlowConfusionFlag } from "@/lib/onboarding/first-session-flow";
import {
  trackConfusionDetected,
  trackOnboardingClarityEvent,
  trackOverwhelmedExit,
  ONBOARDING_CLARITY_EVENTS,
} from "@/lib/onboarding/onboarding-observation";
import type { ConfusionLevel } from "@/types/onboarding-clarity";

const NAV_KEY = "voicememory_onboarding_nav";

interface NavRecord {
  recent: Array<{ path: string; at: string }>;
  settingsBeforeEntry: boolean;
  archiveBeforeEntry: boolean;
  recorderStarted: boolean;
  recorderCompleted: boolean;
  revisitTouched: boolean;
}

function isBrowser(): boolean {
  return typeof window !== "undefined";
}

function readNav(): NavRecord {
  if (!isBrowser()) {
    return {
      recent: [],
      settingsBeforeEntry: false,
      archiveBeforeEntry: false,
      recorderStarted: false,
      recorderCompleted: false,
      revisitTouched: false,
    };
  }
  try {
    const raw = localStorage.getItem(NAV_KEY);
    if (!raw) return defaultNav();
    return { ...defaultNav(), ...(JSON.parse(raw) as NavRecord) };
  } catch {
    return defaultNav();
  }
}

function defaultNav(): NavRecord {
  return {
    recent: [],
    settingsBeforeEntry: false,
    archiveBeforeEntry: false,
    recorderStarted: false,
    recorderCompleted: false,
    revisitTouched: false,
  };
}

function writeNav(nav: NavRecord): void {
  if (!isBrowser()) return;
  localStorage.setItem(NAV_KEY, JSON.stringify(nav));
}

export function recordOnboardingPageView(path: string): void {
  const nav = readNav();
  const now = new Date().toISOString();
  nav.recent = [...nav.recent, { path, at: now }].slice(-12);

  const entries = getMemoryEligibleEntries();
  const hasEntry = entries.length > 0;

  if (path.startsWith("/settings") && !hasEntry) {
    nav.settingsBeforeEntry = true;
  }
  if (path.startsWith("/archive") && !hasEntry) {
    nav.archiveBeforeEntry = true;
  }
  if (path.startsWith("/entry/")) {
    nav.revisitTouched = true;
  }

  writeNav(nav);
  evaluateConfusion(nav);
}

export function markRecorderStarted(): void {
  const nav = readNav();
  nav.recorderStarted = true;
  writeNav(nav);
}

export function markRecorderCompleted(): void {
  const nav = readNav();
  nav.recorderCompleted = true;
  writeNav(nav);
}

export function markRecorderAbandoned(): void {
  const nav = readNav();
  nav.recorderStarted = true;
  nav.recorderCompleted = false;
  writeNav(nav);
  trackOnboardingClarityEvent(ONBOARDING_CLARITY_EVENTS.recorderAbandoned);
  evaluateConfusion(nav);
}

function rapidBounces(recent: NavRecord["recent"]): number {
  if (recent.length < 4) return 0;
  const windowMs = 90 * 1000;
  const last = new Date(recent[recent.length - 1].at).getTime();
  let count = 0;
  for (let i = recent.length - 2; i >= 0; i -= 1) {
    const at = new Date(recent[i].at).getTime();
    if (last - at > windowMs) break;
    count += 1;
  }
  return count;
}

function evaluateConfusion(nav: NavRecord): ConfusionLevel {
  const signals: string[] = [];
  let score = 0;

  const bounces = rapidBounces(nav.recent);
  if (bounces >= 3) {
    score += 2;
    signals.push("Rapid page changes");
  }

  if (nav.settingsBeforeEntry) {
    score += 1;
    signals.push("Settings before first note");
  }
  if (nav.archiveBeforeEntry) {
    score += 1;
    signals.push("Archive opened before first note");
  }
  if (nav.recorderStarted && !nav.recorderCompleted) {
    score += 2;
    signals.push("Recorder abandoned");
  }
  if (!nav.revisitTouched && getMemoryEligibleEntries().length >= 2) {
    const events = readLocalEvents();
    if (!events.some((e) => e.name === "revisit_opened")) {
      score += 1;
      signals.push("No revisit interaction yet");
    }
  }

  const confusionEvents = readLocalEvents().filter(
    (e) => e.name === "first_session_confusion" || e.name === "confusion_detected",
  ).length;
  score += Math.min(2, confusionEvents);

  let level: ConfusionLevel = "clear";
  if (score >= 4) level = "confused";
  else if (score >= 2) level = "uncertain";

  if (bounces >= 3) {
    trackOnboardingClarityEvent(ONBOARDING_CLARITY_EVENTS.rapidNavigation);
  }

  if (level !== "clear") {
    recordFlowConfusionFlag();
    trackConfusionDetected(level, signals.join("; ") || "navigation");
  }
  if (level === "confused") {
    trackOverwhelmedExit(signals.join("; ") || "navigation");
  }

  return level;
}

export function assessConfusionLevel(): {
  level: ConfusionLevel;
  signals: string[];
} {
  const nav = readNav();
  const signals: string[] = [];
  if (rapidBounces(nav.recent) >= 3) signals.push("Rapid navigation");
  if (nav.settingsBeforeEntry) signals.push("Settings before first entry");
  if (nav.archiveBeforeEntry) signals.push("Archive before first entry");
  if (nav.recorderStarted && !nav.recorderCompleted) signals.push("Recorder abandoned");

  let level: ConfusionLevel = "clear";
  if (signals.length >= 3) level = "confused";
  else if (signals.length >= 1) level = "uncertain";

  return { level, signals };
}
