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

/** Primary UI vocabulary banned unless annotated — see CUSTOMER_LANGUAGE.md */
export const CUSTOMER_LANGUAGE_BANNED_PATTERNS: ReadonlyArray<{
  re: RegExp;
  label: string;
}> = [
  { re: /\bbelief\b/i, label: "belief" },
  { re: /\bproof\b/i, label: "proof" },
  { re: /\btheory\b/i, label: "theory" },
  { re: /\bdiagnosis\b/i, label: "diagnosis" },
  { re: /\bblind spot\b/i, label: "blind spot" },
  { re: /\bobjective\b/i, label: "objective" },
  { re: /\bsignal confidence\b/i, label: "signal confidence" },
  { re: /\bpattern certainty\b/i, label: "pattern certainty" },
] as const;

/** Paths scanned for consumer copy — relative to repo root. */
export const CONSUMER_COPY_SCAN_FILES = [
  "packages/shared/lib/site/web-marketing-copy.ts",
  "packages/shared/lib/product/brand-copy.ts",
  "packages/shared/lib/trust-copy.ts",
  "apps/web/app/layout.tsx",
  "apps/web/app/manifest.ts",
  "apps/web/app/page.tsx",
  "apps/web/app/privacy/page.tsx",
  "apps/web/app/terms/page.tsx",
  "apps/web/app/safety/page.tsx",
  "apps/web/app/contact/page.tsx",
  "apps/web/components/SiteHeader.tsx",
  "apps/web/components/SiteFooter.tsx",
  "apps/web/components/trust/TrustPageShell.tsx",
] as const;

/** Internal-only paths — allowed to mention legacy/provider terms. */
export const CONSUMER_BRAND_ALLOWLIST_PATHS = [
  "packages/shared/lib/openai.ts",
  "packages/shared/lib/server/",
  "apps/api/",
  "apps/web/app/api/",
  "apps/web/components/internal/",
  "apps/web/app/internal/",
  "apps/web/archived-consumer-routes/",
  "packages/shared/lib/reliability/consumer-brand-audit.ts",
  "packages/shared/lib/reliability/consumer-brand-audit-tests.ts",
  "scripts/validate-consumer-brand-audit.mjs",
  "docs/product/CUSTOMER_LANGUAGE.md",
  "docs/product/LEGACY_IDENTIFIER_EXCEPTIONS.md",
] as const;

/** Documented exceptions — not product branding. */
export const CONSUMER_BRAND_LITERAL_ALLOWLIST = {
  "hello@archiveme.app": "Primary customer contact email",
  "support@archiveme.app": "Billing/support alias — same inbox via DNS forward",
  "hello@voicememory.app": "Legacy inbound — internal redirect only, not published",
} as const;

/** Annotated customer-language exceptions in web copy. */
export const CUSTOMER_LANGUAGE_LITERAL_ALLOWLIST = {
  "ArchiveMe resurfaces your own voice reflections. It is not therapy, counseling, medical advice, or a diagnosis.":
    "Negative disclaimer",
  "No diagnosis":
    "Safety section — negated claim",
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

function isCustomerLanguageAllowlisted(literal: string): boolean {
  if (literal in CUSTOMER_LANGUAGE_LITERAL_ALLOWLIST) return true;
  const lower = literal.toLowerCase();
  if (lower.includes("not therapy") || lower.includes("not diagnos") || lower.includes("not a diagnosis")) return true;
  if (lower.includes("not medical") || lower.includes("not a chat")) return true;
  if (lower.includes("no diagnosis")) return true;
  return false;
}

export function scanConsumerCopyFile(
  relPath: string,
  source: string,
): string[] {
  const violations: string[] = [];
  for (const literal of extractStringLiterals(source)) {
    if (/@[a-z0-9.-]+\.[a-z]{2,}/i.test(literal)) continue;
    if (isCustomerLanguageAllowlisted(literal)) continue;
    for (const { re, label } of CONSUMER_BANNED_PATTERNS) {
      if (re.test(literal)) {
        violations.push(`${relPath}: banned "${label}" in "${literal.slice(0, 80)}"`);
      }
    }
    for (const { re, label } of CUSTOMER_LANGUAGE_BANNED_PATTERNS) {
      if (re.test(literal)) {
        violations.push(`${relPath}: banned vocabulary "${label}" in "${literal.slice(0, 80)}"`);
      }
    }
    if (/hello@voicememory\.app|careosapp\.co\.uk/i.test(literal)) {
      violations.push(`${relPath}: legacy contact in "${literal.slice(0, 80)}"`);
    }
  }
  return violations;
}
