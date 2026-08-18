import { readFileSync } from "node:fs";
import { join } from "node:path";

import {
  ACTION_PLAN,
  buildMobileWebParityAudit,
  EXECUTIVE_SUMMARY,
  MOBILE_WEB_PARITY_AUDIT_DOC,
  PARITY_CLASSIFICATION_RULES,
  type ParityLaunchClassification,
} from "@/lib/mobile/mobile-web-parity-audit";

const REQUIRED_CLASSIFICATIONS: ParityLaunchClassification[] = [
  "needed_for_launch",
  "later",
  "web_only",
  "remove_or_hide",
];

const REQUIRED_FEATURE_KEYWORDS = [
  "Visual tone",
  "Automatic time-of-day tone",
  "Ambient adaptation",
  "PWA install prompt",
  "Did this help",
  "Privacy page",
  "Pricing / paywall",
  "Record",
  "Search",
  "Export",
  "Action items",
  "Details / fact ledger",
  "Memory controls",
  "Surfacing controls",
] as const;

const BANNED_AUDIT_COPY = [
  /\bVoiceMemory\b/i,
  /\bChatGPT\b/i,
  /\bOpenAI processing\b/i,
  /\bpowered by ChatGPT\b/i,
] as const;

export function runMobileWebParityAuditTests(): { failures: string[] } {
  const failures: string[] = [];
  const root = process.cwd();
  const audit = buildMobileWebParityAudit();

  const check = (name: string, fn: () => void) => {
    try {
      fn();
    } catch (err) {
      failures.push(`${name}: ${err instanceof Error ? err.message : String(err)}`);
    }
  };

  check("audit doc exists", () => {
    const docPath = join(root, MOBILE_WEB_PARITY_AUDIT_DOC);
    readFileSync(docPath, "utf8");
  });

  check("all four classifications are defined", () => {
    const ids = PARITY_CLASSIFICATION_RULES.map((r) => r.id);
    for (const required of REQUIRED_CLASSIFICATIONS) {
      if (!ids.includes(required)) {
        throw new Error(`missing classification rule: ${required}`);
      }
    }
  });

  check("all four classifications appear in feature rows", () => {
    const used = new Set(audit.features.map((f) => f.classification));
    for (const required of REQUIRED_CLASSIFICATIONS) {
      if (!used.has(required)) {
        throw new Error(`no feature uses classification: ${required}`);
      }
    }
  });

  check("audit states mobile is primary distribution platform", () => {
    const doc = readFileSync(join(root, MOBILE_WEB_PARITY_AUDIT_DOC), "utf8");
    const combined = [
      doc,
      EXECUTIVE_SUMMARY.mobileFirstDistribution,
      EXECUTIVE_SUMMARY.recommendation,
      ...ACTION_PLAN,
    ].join("\n");
    if (!/primary distribution platform/i.test(combined)) {
      throw new Error("missing primary distribution platform statement");
    }
    if (!/mobile-first|mobile as the primary/i.test(combined)) {
      throw new Error("missing mobile-first distribution guidance");
    }
  });

  check("audit warns against blind web-to-mobile porting", () => {
    const doc = readFileSync(join(root, MOBILE_WEB_PARITY_AUDIT_DOC), "utf8");
    if (!/do not blindly port web features to mobile/i.test(doc)) {
      throw new Error("missing do-not-blindly-port guidance");
    }
    if (!/Do not port web personalization/i.test(doc)) {
      throw new Error("missing personalization deferral");
    }
  });

  check("required features are classified", () => {
    const names = audit.features.map((f) => f.feature);
    for (const keyword of REQUIRED_FEATURE_KEYWORDS) {
      const match = names.find((n) => n.includes(keyword) || keyword.includes(n));
      if (!match) {
        throw new Error(`missing feature row for: ${keyword}`);
      }
    }
    const byName = (fragment: string) =>
      audit.features.find((f) => f.feature.includes(fragment));
    if (byName("Visual tone")?.classification !== "web_only") {
      throw new Error("visual tone should be web_only");
    }
    if (byName("Ambient adaptation")?.classification !== "later") {
      throw new Error("ambient adaptation should be later");
    }
    if (byName("PWA install prompt")?.classification !== "web_only") {
      throw new Error("PWA install prompt should be web_only");
    }
    const feedback = audit.features.find((f) => f.feature.includes("Did this help"));
    if (feedback?.classification !== "later") {
      throw new Error("session feedback should be later");
    }
  });

  check("launch-critical surfaces use needed_for_launch", () => {
    const launchIds = [
      "privacy-page",
      "pricing-paywall",
      "record",
      "search",
      "export",
      "action-items",
      "details-fact-ledger",
    ];
    for (const id of launchIds) {
      const row = audit.features.find((f) => f.id === id);
      if (!row) throw new Error(`missing feature id: ${id}`);
      if (row.classification !== "needed_for_launch") {
        throw new Error(`${row.feature} should be needed_for_launch`);
      }
    }
  });

  check("internal routes are not mobile parity requirements", () => {
    const internal = audit.features.find((f) => f.feature.includes("Internal dashboards"));
    if (!internal || internal.classification !== "web_only") {
      throw new Error("internal dashboards should be web_only");
    }
    const doc = readFileSync(join(root, MOBILE_WEB_PARITY_AUDIT_DOC), "utf8");
    if (!/not mobile parity requirements/i.test(doc)) {
      throw new Error("doc should state internal routes are not parity requirements");
    }
  });

  check("audit doc avoids consumer VoiceMemory/ChatGPT/OpenAI headline copy", () => {
    const doc = readFileSync(join(root, MOBILE_WEB_PARITY_AUDIT_DOC), "utf8");
    for (const re of BANNED_AUDIT_COPY) {
      if (re.test(doc)) {
        throw new Error(`audit doc contains banned consumer copy: ${re}`);
      }
    }
    if (!/Competitor comparison/.test(doc) || !/remove_or_hide/.test(doc)) {
      throw new Error("competitor comparison should be classified remove_or_hide");
    }
  });

  check("action plan has six steps", () => {
    if (ACTION_PLAN.length < 6) {
      throw new Error("action plan too short");
    }
  });

  return { failures };
}
