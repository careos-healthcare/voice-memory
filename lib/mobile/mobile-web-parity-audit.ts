/**
 * Mobile vs web/PWA feature parity audit — classification source of truth.
 * Do not treat this as a porting checklist; mobile remains the distribution priority.
 */

export type ParityLaunchClassification =
  | "needed_for_launch"
  | "later"
  | "web_only"
  | "remove_or_hide";

export type ParityPlatformPresence = "yes" | "partial" | "no" | "n/a";

export type MobileWebParityFeature = {
  id: string;
  feature: string;
  web: ParityPlatformPresence;
  mobile: ParityPlatformPresence;
  userValue: string;
  classification: ParityLaunchClassification;
  decision: string;
  reason: string;
  action: string;
};

export type MobileWebParityAudit = {
  generatedAt: string;
  executiveSummary: {
    mobileMissingLaunchCritical: string;
    webLegacySurfaces: string;
    mobileFirstDistribution: string;
    recommendation: string;
  };
  classificationRules: ReadonlyArray<{
    id: ParityLaunchClassification;
    label: string;
    definition: string;
  }>;
  features: MobileWebParityFeature[];
  actionPlan: string[];
  inspectedPaths: {
    web: string[];
    mobile: string[];
  };
};

export const MOBILE_WEB_PARITY_AUDIT_DOC = "docs/MOBILE_WEB_PARITY_AUDIT.md";

export const PARITY_CLASSIFICATION_RULES: MobileWebParityAudit["classificationRules"] = [
  {
    id: "needed_for_launch",
    label: "Needed for launch",
    definition:
      "Blocks mobile launch or directly affects first save, second save, Day 2, trust, paywall, privacy, or purchase.",
  },
  {
    id: "later",
    label: "Later",
    definition: "Useful but not launch-blocking; revisit after early testers.",
  },
  {
    id: "web_only",
    label: "Web only",
    definition: "Useful on desktop/PWA but not required in the native Flutter app.",
  },
  {
    id: "remove_or_hide",
    label: "Remove or hide",
    definition:
      "Public web surface adds confusion, old brand risk, internal complexity, or should not drive mobile scope.",
  },
] as const;

const FEATURES: Omit<MobileWebParityFeature, "id">[] = [
  {
    feature: "Visual tone",
    web: "yes",
    mobile: "no",
    userValue: "Personal aesthetic preference on long desktop sessions.",
    classification: "web_only",
    decision: "Do not port to mobile before launch.",
    reason: "Native app uses system theme and focused capture surfaces; tone prefs are desktop polish.",
    action: "Keep in web Settings only; revisit post-launch if users ask.",
  },
  {
    feature: "Automatic time-of-day tone",
    web: "yes",
    mobile: "no",
    userValue: "Subtle ambient UI shift by time of day on web.",
    classification: "later",
    decision: "Defer on mobile.",
    reason: "Nice ambient detail; no impact on record, trust, or paywall.",
    action: "Leave web-only for now.",
  },
  {
    feature: "Ambient adaptation",
    web: "yes",
    mobile: "no",
    userValue: "Warmth/contrast comfort adjustments on web.",
    classification: "later",
    decision: "Defer on mobile.",
    reason: "Accessibility-adjacent but not launch-blocking; mobile has native contrast settings.",
    action: "Monitor accessibility feedback after launch.",
  },
  {
    feature: "PWA install prompt",
    web: "yes",
    mobile: "n/a",
    userValue: "Add web app to home screen on Chromium browsers.",
    classification: "web_only",
    decision: "Keep web-only; never port to Flutter.",
    reason: "Native apps install via App Store / Play; prompt is PWA-specific.",
    action: "Show only when beforeinstallprompt is available; hide otherwise (already gated).",
  },
  {
    feature: "“Did this help?” session feedback",
    web: "yes",
    mobile: "partial",
    userValue: "Qualitative session outcome for retention learning.",
    classification: "later",
    decision: "Optional parity after aha/proof moments.",
    reason: "Useful for founder learning; not required for first save or Day 2.",
    action: "Keep web overlay; mobile has aha feedback rows — unify metrics later.",
  },
  {
    feature: "Landing / marketing home",
    web: "yes",
    mobile: "n/a",
    userValue: "Acquisition story, demo, proof wall on desktop.",
    classification: "web_only",
    decision: "Web acquisition surface only.",
    reason: "Mobile distribution is store listing + in-app first-run, not marketing homepage.",
    action: "Keep web home lean on mobile web; do not expand Flutter scope.",
  },
  {
    feature: "Privacy page",
    web: "yes",
    mobile: "yes",
    userValue: "Trust, store review, legal transparency.",
    classification: "needed_for_launch",
    decision: "Required on both platforms.",
    reason: "App Store / Play and user trust require reachable privacy policy.",
    action: "Mobile in-app summary + link to deployed web policy.",
  },
  {
    feature: "Terms / safety pages",
    web: "yes",
    mobile: "partial",
    userValue: "Legal and emotional-safety references.",
    classification: "needed_for_launch",
    decision: "Web canonical; mobile links out where needed.",
    reason: "Store compliance and trust; mobile opens external trust URLs.",
    action: "Keep web pages current; mobile Terms via external link is sufficient.",
  },
  {
    feature: "Account / sign-in",
    web: "yes",
    mobile: "yes",
    userValue: "Encrypted backup and cross-device restore.",
    classification: "needed_for_launch",
    decision: "Required where backup is offered.",
    reason: "Protect-archive and restore flows depend on auth.",
    action: "Continue native auth QA; do not block launch on web Stripe account UI.",
  },
  {
    feature: "Pricing / paywall",
    web: "yes",
    mobile: "yes",
    userValue: "Pro upgrade and restore.",
    classification: "needed_for_launch",
    decision: "Platform-specific billing on both.",
    reason: "Revenue path is launch-critical; Stripe (web) and RevenueCat (mobile) are intentional splits.",
    action: "Keep separate billing stacks; align copy not checkout mechanics.",
  },
  {
    feature: "Record",
    web: "yes",
    mobile: "yes",
    userValue: "Core voice capture loop.",
    classification: "needed_for_launch",
    decision: "Must work on mobile first.",
    reason: "Primary product action.",
    action: "Prioritize mobile record QA over web personalization.",
  },
  {
    feature: "Save entry",
    web: "yes",
    mobile: "yes",
    userValue: "Persist transcript, reflection, and audio locally.",
    classification: "needed_for_launch",
    decision: "Required on mobile.",
    reason: "First save and second save depend on reliable save path.",
    action: "No web-only save enhancements before mobile launch.",
  },
  {
    feature: "Archive / journal home",
    web: "yes",
    mobile: "yes",
    userValue: "Browse beliefs, patterns, and entries.",
    classification: "needed_for_launch",
    decision: "Mobile Patterns tab is primary archive home.",
    reason: "Return loop and archive value live here.",
    action: "Keep /archive-belief parity; journal list remains dev-gated on mobile.",
  },
  {
    feature: "Search",
    web: "yes",
    mobile: "partial",
    userValue: "Find past reflections and archive content.",
    classification: "needed_for_launch",
    decision: "Mobile must ship usable search, not web semantic parity.",
    reason: "Users need to find entries; mobile has Ask Archive + journal search engine.",
    action: "Do not port web mood/theme filters pre-launch; validate Ask Archive + pins/collections.",
  },
  {
    feature: "Pins / pinned evidence",
    web: "partial",
    mobile: "yes",
    userValue: "Keep important evidence visible.",
    classification: "needed_for_launch",
    decision: "Mobile leads; web partial is acceptable.",
    reason: "Mobile /pinned-evidence is consumer-ready.",
    action: "No port required from web.",
  },
  {
    feature: "Collections",
    web: "partial",
    mobile: "yes",
    userValue: "Group related entries.",
    classification: "needed_for_launch",
    decision: "Mobile-native feature is launch scope.",
    reason: "Organizational control supports retention.",
    action: "Keep mobile collections; web can stay partial.",
  },
  {
    feature: "Export",
    web: "yes",
    mobile: "partial",
    userValue: "Data portability and ownership.",
    classification: "needed_for_launch",
    decision: "Mobile JSON export is sufficient for launch.",
    reason: "Store review expects export; markdown/print are enhancements.",
    action: "Ship mobile JSON export; add formats later if testers request.",
  },
  {
    feature: "Archive packs",
    web: "no",
    mobile: "yes",
    userValue: "Scoped sub-archives with instructions.",
    classification: "needed_for_launch",
    decision: "Mobile-only launch feature.",
    reason: "Already shipped on Flutter; not a web parity requirement.",
    action: "Do not port to web before mobile launch.",
  },
  {
    feature: "Action items",
    web: "no",
    mobile: "yes",
    userValue: "Remember-this tasks linked to entries.",
    classification: "needed_for_launch",
    decision: "Mobile-only launch feature.",
    reason: "Core mobile workflow; trust copy references it.",
    action: "Keep mobile-only.",
  },
  {
    feature: "Details / fact ledger",
    web: "partial",
    mobile: "yes",
    userValue: "Saved facts separate from full entries.",
    classification: "needed_for_launch",
    decision: "Mobile /details is launch scope.",
    reason: "Users save durable facts; mobile screen is complete.",
    action: "No web port required pre-launch.",
  },
  {
    feature: "Memory controls (scope / governance)",
    web: "partial",
    mobile: "yes",
    userValue: "Control what connects to memory and surfacing.",
    classification: "needed_for_launch",
    decision: "Mobile is ahead; keep as-is.",
    reason: "Trust and control are launch-critical; mobile has explicit scope modes.",
    action: "Do not simplify mobile to match thinner web settings.",
  },
  {
    feature: "Surfacing controls",
    web: "partial",
    mobile: "yes",
    userValue: "Choose what resurfaces and when.",
    classification: "needed_for_launch",
    decision: "Required on mobile.",
    reason: "User agency over resurfacing is core trust.",
    action: "Continue mobile memory widget QA.",
  },
  {
    feature: "Hypothetical / Not about me",
    web: "partial",
    mobile: "yes",
    userValue: "Mark entries that should not define self-model.",
    classification: "needed_for_launch",
    decision: "Required on mobile entry editors.",
    reason: "Prevents wrong self-inference; tested on mobile.",
    action: "No web port pressure.",
  },
  {
    feature: "Sensitive / Do not surface",
    web: "partial",
    mobile: "yes",
    userValue: "Protect sensitive content from resurfacing.",
    classification: "needed_for_launch",
    decision: "Required on mobile.",
    reason: "Safety and trust at launch.",
    action: "Keep mobile guards; web partial is fine.",
  },
  {
    feature: "Preserve original",
    web: "partial",
    mobile: "yes",
    userValue: "Keep verbatim evidence intact.",
    classification: "needed_for_launch",
    decision: "Required on mobile.",
    reason: "Archive integrity feature.",
    action: "No change needed.",
  },
  {
    feature: "Topic shift guard",
    web: "partial",
    mobile: "partial",
    userValue: "Detect when a new topic should not inherit old thread context.",
    classification: "later",
    decision: "Defer full parity.",
    reason: "Helpful governance edge case; not blocking first-week loop.",
    action: "Revisit after 20–50 testers.",
  },
  {
    feature: "Aha moment",
    web: "partial",
    mobile: "yes",
    userValue: "First archive recognition beat.",
    classification: "later",
    decision: "Mobile implementation is sufficient for launch.",
    reason: "Mobile first_aha_moment_card exists; web discovery differs.",
    action: "Tune copy from mobile feedback, not web parity.",
  },
  {
    feature: "Pro trust card / value clarity",
    web: "yes",
    mobile: "yes",
    userValue: "Explain Pro without pressure before paywall.",
    classification: "needed_for_launch",
    decision: "Required on both; platform-specific triggers.",
    reason: "Conversion after value moment needs trust framing.",
    action: "Align ArchiveMe copy; keep separate trigger engines.",
  },
  {
    feature: "Commercial metrics / launch QA",
    web: "yes",
    mobile: "partial",
    userValue: "Founder evidence for store and revenue readiness.",
    classification: "web_only",
    decision: "Internal/founder tooling on web.",
    reason: "Not consumer product surface.",
    action: "Use /internal/launch and mobile-readiness reports.",
  },
  {
    feature: "Internal dashboards",
    web: "yes",
    mobile: "no",
    userValue: "Founder command center, activation/return/conversion readouts.",
    classification: "web_only",
    decision: "Never port to consumer mobile.",
    reason: "Gated /internal/* routes are not mobile parity requirements.",
    action: "Keep noindex; do not add to Flutter nav.",
  },
  {
    feature: "Web-only archive analysis pages",
    web: "yes",
    mobile: "no",
    userValue: "Theories, blind-spots, discover, archive-detail hub on desktop.",
    classification: "web_only",
    decision: "Do not port wholesale to mobile.",
    reason: "Simplicity mode demotes these on web; mobile uses Patterns + Ask Archive.",
    action: "Hide from public primary nav; treat as experimental desktop depth.",
  },
  {
    feature: "Push / notification internal pages",
    web: "yes",
    mobile: "partial",
    userValue: "Founder verification of FCM/APNs readiness.",
    classification: "web_only",
    decision: "Internal evidence only.",
    reason: "Consumer push lives in Flutter; internal pages are QA.",
    action: "Use /internal/mobile-push-readiness; not a parity gap.",
  },
  {
    feature: "Competitor comparison (homepage)",
    web: "yes",
    mobile: "no",
    userValue: "Desktop acquisition positioning.",
    classification: "remove_or_hide",
    decision: "Remove or hide from public primary product path.",
    reason: "Consumer-facing competitor framing adds brand risk and scope creep.",
    action: "Demote HomepageChatGptComparison from default mobile web stack; do not port to Flutter.",
  },
  {
    feature: "Desktop personalization settings block",
    web: "yes",
    mobile: "no",
    userValue: "Reflection goals, listening mode, full-detail quiet mode, photo prefs.",
    classification: "later",
    decision: "Selective mobile ports only if testers block.",
    reason: "Web settings breadth exceeds mobile launch scope.",
    action: "Keep mobile settings focused on archive org, security, export, privacy.",
  },
  {
    feature: "Web archive permanence (/archive export hub)",
    web: "yes",
    mobile: "partial",
    userValue: "JSON/Markdown/ZIP import-export and ownership panel.",
    classification: "later",
    decision: "Mobile JSON export covers launch minimum.",
    reason: "Full permanence hub is web-heavy; mobile export + delete account suffices initially.",
    action: "Add markdown/zip on mobile only if store review or testers require.",
  },
  {
    feature: "Retention loop (Day 2 / reminders)",
    web: "partial",
    mobile: "yes",
    userValue: "Return after first archive value.",
    classification: "needed_for_launch",
    decision: "Mobile-native retention is launch scope.",
    reason: "Distribution priority is mobile return loop.",
    action: "Prioritize Flutter reminder + day-2 cards over web prompt parity.",
  },
];

export const INSPECTED_WEB_PATHS = [
  "app/settings/page.tsx",
  "components/settings/*",
  "components/retention/SessionOutcomePrompt.tsx",
  "components/mobile/InstallPrompt.tsx",
  "components/ActivationOnboarding.tsx",
  "components/OnboardingBanner.tsx",
  "components/Recorder.tsx",
  "components/SiteHeader.tsx",
  "app/page.tsx",
  "app/privacy/page.tsx",
  "app/pricing/*",
  "app/archive*",
  "app/internal/*",
  "lib/product/*",
  "lib/retention/*",
  "lib/distribution/*",
  "lib/mobile/*",
] as const;

export const INSPECTED_MOBILE_PATHS = [
  "apps/voicememory_mobile/lib/screens/settings_screen.dart",
  "apps/voicememory_mobile/lib/screens/record_screen.dart",
  "apps/voicememory_mobile/lib/screens/journal_screen.dart",
  "apps/voicememory_mobile/lib/screens/privacy_screen.dart",
  "apps/voicememory_mobile/lib/screens/paywall_screen.dart",
  "apps/voicememory_mobile/lib/screens/action_items_screen.dart",
  "apps/voicememory_mobile/lib/screens/fact_ledger_screen.dart",
  "apps/voicememory_mobile/lib/screens/archive_packs_screen.dart",
  "apps/voicememory_mobile/lib/widgets/retention/*",
  "apps/voicememory_mobile/lib/widgets/aha/*",
  "apps/voicememory_mobile/lib/widgets/trust/*",
  "apps/voicememory_mobile/lib/widgets/memory/*",
  "apps/voicememory_mobile/test/* (settings, privacy, record, paywall, search, export, action items, details)",
] as const;

export const EXECUTIVE_SUMMARY = {
  mobileMissingLaunchCritical:
    "No launch-blocking gaps found. Mobile already covers record, archive, search (Ask Archive + filters), export (JSON), action items, details, packs, collections, pins, memory controls, privacy, and RevenueCat paywall. Remaining gaps are format depth (markdown/print export) and web-style semantic search filters — both classified later.",
  webLegacySurfaces:
    "Web still carries desktop personalization (visual tone, ambient adaptation), PWA install prompt, marketing homepage with competitor comparison, session outcome overlay, and many demoted archive analysis routes. These should not expand mobile scope.",
  mobileFirstDistribution:
    "Yes — Flutter is the primary distribution platform. Web/PWA is support: landing, privacy, pricing/account, and internal founder tooling.",
  recommendation:
    "Keep mobile distribution priority. Do not blindly port web settings or experimental archive pages to Flutter. Use web for trust URLs, Stripe checkout, and internal QA. Revisit parity after 20–50 testers.",
} as const;

export const ACTION_PLAN = [
  "Keep mobile as the primary distribution platform.",
  "Do not port web personalization settings (visual tone, ambient adaptation, auto tone) before launch.",
  "Keep PWA install prompt gated on beforeinstallprompt only; hide when unavailable.",
  "Keep web focused on landing, privacy, pricing/account, and /internal dashboards.",
  "Continue native mobile QA on record, archive, paywall, privacy, export, and memory controls.",
  "Revisit mobile/web parity after 20–50 testers — not before.",
] as const;

export function buildMobileWebParityAudit(now = new Date()): MobileWebParityAudit {
  return {
    generatedAt: now.toISOString(),
    executiveSummary: { ...EXECUTIVE_SUMMARY },
    classificationRules: PARITY_CLASSIFICATION_RULES,
    features: FEATURES.map((f, i) => ({
      id: f.feature
        .toLowerCase()
        .replace(/[^a-z0-9]+/g, "-")
        .replace(/^-|-$/g, ""),
      ...f,
    })),
    actionPlan: [...ACTION_PLAN],
    inspectedPaths: {
      web: [...INSPECTED_WEB_PATHS],
      mobile: [...INSPECTED_MOBILE_PATHS],
    },
  };
}

export function formatMobileWebParityAuditMarkdown(audit: MobileWebParityAudit): string {
  const lines: string[] = [
    "# Mobile / Web Parity Audit — ArchiveMe",
    "",
    `Generated: ${audit.generatedAt}`,
    "",
    "> Mobile is the primary distribution platform. Do not blindly port web features to mobile.",
    "",
    "## A. Executive summary",
    "",
    "**Is mobile missing anything launch-critical from web?**",
    "",
    audit.executiveSummary.mobileMissingLaunchCritical,
    "",
    "**Is web carrying legacy/experimental surfaces that should not drive mobile?**",
    "",
    audit.executiveSummary.webLegacySurfaces,
    "",
    "**Should distribution continue mobile-first?**",
    "",
    audit.executiveSummary.mobileFirstDistribution,
    "",
    "**Recommendation**",
    "",
    audit.executiveSummary.recommendation,
    "",
    "## B. Feature comparison table",
    "",
    "| Feature | Web | Mobile | User value | Classification | Decision | Reason | Action |",
    "| --- | --- | --- | --- | --- | --- | --- | --- |",
  ];

  for (const f of audit.features) {
    lines.push(
      `| ${f.feature} | ${f.web} | ${f.mobile} | ${f.userValue} | ${f.classification} | ${f.decision} | ${f.reason} | ${f.action} |`,
    );
  }

  lines.push(
    "",
    "## C. Classification rules",
    "",
    ...audit.classificationRules.map(
      (r) => `- **${r.id}** (${r.label}): ${r.definition}`,
    ),
    "",
    "## D. Expected classifications (spot check)",
    "",
    "- Visual tone → web_only",
    "- Automatic time-of-day tone → later",
    "- Ambient adaptation → later",
    "- PWA install prompt → web_only",
    "- Session feedback overlay → later",
    "- Privacy / pricing / record / search / export / action items / details / memory controls → needed_for_launch",
    "- Internal dashboards → web_only",
    "- Competitor comparison → remove_or_hide",
    "",
    "## E. Action plan",
    "",
    ...audit.actionPlan.map((step, i) => `${i + 1}. ${step}`),
    "",
    "## F. PWA install prompt",
    "",
    "InstallPrompt already renders only when `beforeinstallprompt` fires and eligibility gates pass. No copy change required for this audit.",
    "",
    "## G. Inspected paths",
    "",
    "### Web",
    "",
    ...audit.inspectedPaths.web.map((p) => `- \`${p}\``),
    "",
    "### Mobile",
    "",
    ...audit.inspectedPaths.mobile.map((p) => `- \`${p}\``),
    "",
    "## Internal note",
    "",
    "Internal `/internal/*` routes are founder tooling — not mobile parity requirements.",
    "",
  );

  return lines.join("\n");
}

export function countByClassification(
  audit: MobileWebParityAudit,
): Record<ParityLaunchClassification, number> {
  const counts: Record<ParityLaunchClassification, number> = {
    needed_for_launch: 0,
    later: 0,
    web_only: 0,
    remove_or_hide: 0,
  };
  for (const f of audit.features) {
    counts[f.classification] += 1;
  }
  return counts;
}
