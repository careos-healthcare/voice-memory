/** Consumer-facing brand/provider exposure guardrails — shared by validate script. */

/** Banned in user-visible product copy (case-insensitive). */
export const CONSUMER_BANNED_PATTERNS: ReadonlyArray<{
  re: RegExp;
  label: string;
}> = [
  { re: /\bVoiceMemory\b/i, label: "VoiceMemory" },
  { re: /\bvoice memory\b/i, label: "voice memory" },
  { re: /\bvoicememory\b/i, label: "voicememory" },
  { re: /\bChatGPT\b/i, label: "ChatGPT" },
  { re: /\bOpenAI processing\b/i, label: "OpenAI processing" },
  { re: /\bpowered by ChatGPT\b/i, label: "powered by ChatGPT" },
  { re: /\bOpenAI memory\b/i, label: "OpenAI memory" },
  { re: /\btrain OpenAI\b/i, label: "train OpenAI" },
  { re: /\btrain our models\b/i, label: "train our models" },
  { re: /\bWhisper\b/i, label: "Whisper" },
  { re: /\bwrapper\b/i, label: "wrapper" },
] as const;

/** Paths scanned for consumer copy — relative to repo root. */
export const CONSUMER_COPY_SCAN_FILES = [
  "lib/product/product-clarity-copy.ts",
  "lib/product/recognition-copy.ts",
  "lib/product/archive-value-copy.ts",
  "lib/product-copy.ts",
  "lib/trust-copy.ts",
  "lib/billing/value-moment-paywall-copy.ts",
  "lib/archive/archive-uniqueness-copy.ts",
  "lib/archive/archive-moat-proof.ts",
  "app/layout.tsx",
  "app/manifest.ts",
  "lib/product/brand-copy.ts",
  "app/privacy/page.tsx",
  "app/terms/page.tsx",
  "app/safety/page.tsx",
  "app/contact/page.tsx",
  "app/page.tsx",
  "components/SiteHeader.tsx",
  "components/trust/TrustPageShell.tsx",
  "app/icon.tsx",
  "app/apple-icon.tsx",
  "components/product/HomepageChatGptComparison.tsx",
  "components/archive/ArchiveUniquenessPanel.tsx",
  "components/billing/ValueMomentPaywall.tsx",
] as const;

/** Internal-only paths — allowed to mention legacy/provider terms. */
export const CONSUMER_BRAND_ALLOWLIST_PATHS = [
  "lib/openai.ts",
  "lib/server/",
  "app/api/",
  "lib/founder-test/",
  "components/internal/",
  "app/internal/",
  "types/founder-test.ts",
  "lib/launch-checklist.ts",
  "lib/onboarding/onboarding-confidence-check.ts",
  "lib/reliability/consumer-brand-audit.ts",
  "lib/reliability/consumer-brand-audit-tests.ts",
  "scripts/validate-consumer-brand-audit.mjs",
] as const;

/** Documented exceptions — not product branding. */
export const CONSUMER_BRAND_LITERAL_ALLOWLIST = {
  "hello@voicememory.app": "Contact email domain — backend identifier",
} as const;

/** Privacy copy must remain transparent about AI processing. */
export const PRIVACY_AI_DISCLOSURE_MARKERS = [
  "AI transcription and analysis",
  "transcription, analysis",
  "may send audio or transcript",
] as const;

export function extractStringLiterals(source: string): string[] {
  const literals: string[] = [];
  const single = /'([^'\\]|\\.)*'/g;
  const double = /"([^"\\]|\\.)*"/g;
  for (const line of source.split("\n")) {
    const trimmed = line.trim();
    if (trimmed.startsWith("//") || trimmed.startsWith("*")) continue;
    if (trimmed.startsWith("import ")) continue;
    for (const re of [single, double]) {
      re.lastIndex = 0;
      for (const match of line.matchAll(re)) {
        const raw = match[0];
        const value = raw.slice(1, -1);
        if (value.includes("${")) continue;
        literals.push(value);
      }
    }
  }
  return literals;
}

export function scanConsumerCopyFile(
  relPath: string,
  source: string,
): string[] {
  const violations: string[] = [];
  for (const literal of extractStringLiterals(source)) {
    if (/@[a-z0-9.-]+\.[a-z]{2,}/i.test(literal)) continue;
    for (const { re, label } of CONSUMER_BANNED_PATTERNS) {
      if (re.test(literal)) {
        violations.push(`${relPath}: banned "${label}" in "${literal.slice(0, 80)}"`);
      }
    }
  }
  return violations;
}
