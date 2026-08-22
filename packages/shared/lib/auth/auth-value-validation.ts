/**
 * Founder validation — auth must feel like protecting value, not asking permission.
 * Read device-local analytics only until conversion rates are known.
 */

import { GUEST_FIRST_AUTH_EVENTS } from "@/lib/auth/guest-first-auth";
import { readLocalEvents } from "@/lib/local-analytics";
import type { AuthTriggerReason } from "@/types/auth-trigger";
import type {
  AuthValueFunnelRow,
  AuthValueValidationReport,
  AuthValueVerdict,
} from "@/types/auth-value-validation";

export const AUTH_VALUE_MAIN_QUESTION =
  "Does sign-in feel like protecting value already created — not permission to start?";

export const AUTH_VALUE_ROADMAP_FREEZE = {
  pausedUntilKnown: [
    "Protect Archive conversion rate",
    "First-working-belief → sign-in conversion",
    "Paywall auth → checkout completion",
  ],
  doNotBuild: [
    "Social login",
    "Firebase",
    "Password auth",
    "Account settings expansion",
    "Enterprise permissions",
  ],
} as const;

/** Manual founder-test scenarios (6). */
export const AUTH_VALUE_MANUAL_SCENARIOS = [
  {
    id: "brand_new",
    title: "Brand new user",
    steps: [
      "Open app (signed out)",
      "Record reflection 1",
      "Record reflection 2",
      "Never see email request",
      "Never feel blocked",
    ],
    pass: "User reaches reflection 2 without thinking about accounts.",
    fail: "Email modal or sign-in wall before reflection 2.",
  },
  {
    id: "first_belief",
    title: "First working belief",
    steps: [
      "Reach 5 reflections",
      "Open Archive (belief home)",
      "See Protect Archive prompt (banner or modal)",
    ],
    pass: '"I should save this."',
    fail: '"Why are you asking for my email?"',
  },
  {
    id: "paywall",
    title: "Paywall flow",
    steps: [
      "Reach value-moment paywall",
      "Tap upgrade",
      "Enter email → verify",
      "Continue directly into checkout",
    ],
    pass: "No dead ends, no repeated prompts, no lost context.",
    fail: "Checkout blocked, modal loops, or context lost after verify.",
  },
  {
    id: "device_protection",
    title: "Device protection",
    steps: [
      "Sign in on Device A",
      "Sign in on Device B",
      "Confirm session/device limits behave",
      "User understands what happened",
    ],
    pass: "Feels like account protection.",
    fail: "Feels broken or unexplained.",
  },
  {
    id: "mobile",
    title: "Mobile",
    steps: [
      "Fresh install, no login",
      "Record immediately",
      "Reach first belief",
      "Protect archive",
      "Restore account on second device",
    ],
    pass: "Archive feels more important than the account.",
    fail: "Login wall before record or account-first framing.",
  },
  {
    id: "analytics",
    title: "Analytics",
    steps: [
      "Check guest_mode_started",
      "protect_archive_clicked",
      "auth_prompt_shown",
      "auth_verified",
      "Protect Archive Conversion Rate on /internal/auth-value-validation",
    ],
    pass: "Funnel visible; conversion interpretable.",
    fail: "Missing events or zero denominators.",
  },
] as const;

const PROTECT_ARCHIVE_PASS_THRESHOLD = 25;
const OVERALL_PASS_THRESHOLD = 20;

function pct(n: number, d: number): number | null {
  if (d <= 0) return null;
  return Math.round((n / d) * 100);
}

function countEvent(name: string, metaFilter?: (meta: Record<string, string> | undefined) => boolean): number {
  return readLocalEvents().filter((e) => {
    if (e.name !== name) return false;
    return metaFilter ? metaFilter(e.meta) : true;
  }).length;
}

function funnelForReason(reason: AuthTriggerReason): AuthValueFunnelRow {
  const promptsShown = countEvent(
    GUEST_FIRST_AUTH_EVENTS.authPromptShown,
    (m) => m?.reason === reason,
  );
  const verified = countEvent(
    GUEST_FIRST_AUTH_EVENTS.authVerified,
    (m) => m?.reason === reason,
  );
  return {
    reason,
    promptsShown,
    verified,
    conversionRate: pct(verified, promptsShown),
  };
}

function buildVerdict(
  protectRate: number | null,
  overallRate: number | null,
): AuthValueVerdict {
  const hasData =
    (protectRate !== null && protectRate > 0) || (overallRate !== null && overallRate > 0);
  if (!hasData) return "insufficient_data";
  if (protectRate !== null && protectRate >= PROTECT_ARCHIVE_PASS_THRESHOLD) {
    return "strong";
  }
  if (protectRate !== null && protectRate < PROTECT_ARCHIVE_PASS_THRESHOLD / 2) {
    return "weak";
  }
  return "mixed";
}

function buildVerdictAnswer(verdict: AuthValueVerdict, protectRate: number | null): string {
  if (verdict === "insufficient_data") {
    return "Ignore conversion on this device until 10+ real users. Collect scenario #2 quotes and the archive-disappearance interview first.";
  }
  if (verdict === "strong") {
    return "Protect Archive conversion suggests sign-in reads as saving value. Safe to keep current auth scope frozen.";
  }
  if (verdict === "weak") {
    return "Low Protect Archive conversion — users may still not feel the archive is worth protecting. Do not expand auth; improve archive pull first.";
  }
  return `Mixed — Protect Archive ${protectRate ?? "—"}%. Keep auth scope frozen until first-belief interviews clarify pass/fail language.`;
}

export function buildAuthValueValidationReport(): AuthValueValidationReport {
  const guestModeStarted = countEvent(GUEST_FIRST_AUTH_EVENTS.guestModeStarted);
  const protectArchiveBannerSeen = countEvent(
    GUEST_FIRST_AUTH_EVENTS.protectArchiveBannerSeen,
  );
  const protectArchiveClicked = countEvent(GUEST_FIRST_AUTH_EVENTS.protectArchiveClicked);
  const authPromptsShown = countEvent(GUEST_FIRST_AUTH_EVENTS.authPromptShown);
  const authVerified = countEvent(GUEST_FIRST_AUTH_EVENTS.authVerified);

  const protectPrompts = countEvent(GUEST_FIRST_AUTH_EVENTS.authPromptShown, (m) =>
    m?.reason === "protect_archive",
  );
  const protectVerified = countEvent(GUEST_FIRST_AUTH_EVENTS.authVerified, (m) =>
    m?.reason === "protect_archive",
  );
  const protectArchiveConversionRate = pct(protectVerified, protectArchiveClicked);

  const beliefPrompts = countEvent(GUEST_FIRST_AUTH_EVENTS.authPromptShown, (m) =>
    m?.reason === "first_working_belief",
  );
  const beliefVerified = countEvent(GUEST_FIRST_AUTH_EVENTS.authVerified, (m) =>
    m?.reason === "first_working_belief",
  );
  const firstWorkingBeliefPromptRate = pct(beliefVerified, beliefPrompts);

  const paywallPrompts = countEvent(GUEST_FIRST_AUTH_EVENTS.authPromptShown, (m) =>
    m?.reason === "pro_paywall",
  );
  const paywallVerified = countEvent(GUEST_FIRST_AUTH_EVENTS.authVerified, (m) =>
    m?.reason === "pro_paywall",
  );
  const paywallPromptToVerifiedRate = pct(paywallVerified, paywallPrompts);

  const overallPromptToVerifiedRate = pct(authVerified, authPromptsShown);

  const reasons: AuthTriggerReason[] = [
    "protect_archive",
    "first_working_belief",
    "pro_paywall",
    "sync_archive",
    "export",
    "cross_device",
    "archive_changed_return",
    "keep_tracking_pro",
  ];
  const funnelByReason = reasons.map(funnelForReason);

  const verdict = buildVerdict(protectArchiveConversionRate, overallPromptToVerifiedRate);

  const lines = [
    `Guest sessions started: ${guestModeStarted}`,
    `Protect banner seen: ${protectArchiveBannerSeen} · clicked: ${protectArchiveClicked}`,
    `Protect Archive conversion (verified ÷ clicked): ${protectRateLabel(protectArchiveConversionRate)}`,
    `Auth prompts shown: ${authPromptsShown} · verified: ${authVerified}`,
    `Overall prompt → verified: ${protectRateLabel(overallPromptToVerifiedRate)}`,
    `Paywall prompt → verified: ${protectRateLabel(paywallPromptToVerifiedRate)}`,
  ];

  return {
    mainQuestion: AUTH_VALUE_MAIN_QUESTION,
    verdict,
    verdictAnswer: buildVerdictAnswer(verdict, protectArchiveConversionRate),
    guestModeStarted,
    protectArchiveBannerSeen,
    protectArchiveClicked,
    protectArchiveConversionRate,
    firstWorkingBeliefPromptRate,
    paywallPromptToVerifiedRate,
    authPromptsShown,
    authVerified,
    overallPromptToVerifiedRate,
    funnelByReason,
    lines,
    pausedBuilds: [...AUTH_VALUE_ROADMAP_FREEZE.doNotBuild],
  };
}

function protectRateLabel(rate: number | null): string {
  if (rate === null) return "— (no data)";
  return `${rate}%`;
}

export function clearAuthValueValidationEventsForEval(): void {
  if (typeof window === "undefined") return;
  try {
    const names = new Set<string>(Object.values(GUEST_FIRST_AUTH_EVENTS));
    const raw = localStorage.getItem("voicememory_local_events");
    if (!raw) return;
    const events = JSON.parse(raw) as Array<{ name: string }>;
    const filtered = events.filter((e) => !names.has(e.name));
    localStorage.setItem("voicememory_local_events", JSON.stringify(filtered));
  } catch {
    /* ignore */
  }
}
