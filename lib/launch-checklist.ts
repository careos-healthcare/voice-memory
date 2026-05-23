export interface LaunchChecklistItem {
  id: string;
  category: string;
  label: string;
  description: string;
}

export const LAUNCH_CHECKLIST: LaunchChecklistItem[] = [
  {
    id: "prod_build",
    category: "Production readiness",
    label: "Production build passes",
    description: "npm run build completes without errors; all routes render.",
  },
  {
    id: "env_keys",
    category: "Production readiness",
    label: "OpenAI keys configured",
    description: "Transcription and analysis API routes work in production environment.",
  },
  {
    id: "privacy_review",
    category: "Privacy review",
    label: "Privacy page accurate",
    description: "Local-first storage, OpenAI processing, export/deletion copy reviewed.",
  },
  {
    id: "data_controls",
    category: "Privacy review",
    label: "Settings data controls work",
    description: "Delete all, export all, reset onboarding, clear reminders, clear Pro preview.",
  },
  {
    id: "mobile_recorder",
    category: "Mobile UX review",
    label: "Mobile recorder UX",
    description: "Mic permission, 60s limit, and processing states usable on small screens.",
  },
  {
    id: "mobile_nav",
    category: "Mobile UX review",
    label: "Core pages on mobile",
    description: "Memory, weekly, settings, and trust pages readable without horizontal scroll.",
  },
  {
    id: "retention_dashboard",
    category: "Retention review",
    label: "Retention indicators",
    description: "/debug/retention shows reflections, streak, days active, feature usage.",
  },
  {
    id: "habit_loop",
    category: "Retention review",
    label: "Habit loop surfaces",
    description: "Streak and reminders visible on home and journal.",
  },
  {
    id: "onboarding_banner",
    category: "Onboarding review",
    label: "First-run onboarding",
    description: "Welcome banner dismisses and fires onboarding_completed locally.",
  },
  {
    id: "empty_states",
    category: "Onboarding review",
    label: "Progressive empty states",
    description: "0/1/few/building/rich messaging guides new users.",
  },
  {
    id: "export_json",
    category: "Export review",
    label: "JSON export",
    description: "Full archive downloads with transcripts and reflections.",
  },
  {
    id: "export_weekly",
    category: "Export review",
    label: "Weekly text export",
    description: "Weekly summary text export works from export and weekly pages.",
  },
  {
    id: "perf_first_load",
    category: "Performance review",
    label: "First load acceptable",
    description: "Home and journal load quickly on mobile network throttling.",
  },
  {
    id: "perf_weekly",
    category: "Performance review",
    label: "Weekly analysis local-only",
    description: "Weekly intelligence computes from local entries without blocking UI.",
  },
  {
    id: "trust_safety",
    category: "Trust / safety review",
    label: "Safety pages live",
    description: "Not therapy / no diagnosis / crisis disclaimer on safety and footer.",
  },
  {
    id: "feedback_local",
    category: "Trust / safety review",
    label: "Feedback stays local",
    description: "Thumbs and optional notes stored in localStorage only.",
  },
];

const CHECKLIST_KEY = "voicememory_launch_checklist";

function isBrowser(): boolean {
  return typeof window !== "undefined";
}

export function getLaunchChecklistState(): Record<string, boolean> {
  if (!isBrowser()) return {};
  try {
    const raw = localStorage.getItem(CHECKLIST_KEY);
    return raw ? (JSON.parse(raw) as Record<string, boolean>) : {};
  } catch {
    return {};
  }
}

export function setLaunchChecklistItem(id: string, checked: boolean): void {
  if (!isBrowser()) return;
  const state = getLaunchChecklistState();
  state[id] = checked;
  localStorage.setItem(CHECKLIST_KEY, JSON.stringify(state));
}

export function resetLaunchChecklist(): void {
  if (!isBrowser()) return;
  localStorage.removeItem(CHECKLIST_KEY);
}

export function getLaunchChecklistProgress(): {
  checked: number;
  total: number;
  percent: number;
} {
  const state = getLaunchChecklistState();
  const total = LAUNCH_CHECKLIST.length;
  const checked = LAUNCH_CHECKLIST.filter((item) => state[item.id]).length;
  return {
    checked,
    total,
    percent: total === 0 ? 0 : Math.round((checked / total) * 100),
  };
}
