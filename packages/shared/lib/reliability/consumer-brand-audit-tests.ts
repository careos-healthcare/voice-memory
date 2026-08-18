import { readFileSync } from "node:fs";
import { join } from "node:path";

import {
  CONSUMER_BANNED_PATTERNS,
  CONSUMER_BRAND_ALLOWLIST_PATHS,
  CONSUMER_BRAND_LITERAL_ALLOWLIST,
  CONSUMER_COPY_SCAN_FILES,
  CUSTOMER_LANGUAGE_BANNED_PATTERNS,
  PRIVACY_AI_DISCLOSURE_MARKERS,
  scanConsumerCopyFile,
} from "./consumer-brand-audit";
import {
  AI_TRANSCRIPTION_ANALYSIS_SUMMARY,
  CONTACT_EMAIL,
  PRIVACY_SECTIONS,
  PROCESSING_PROVIDERS_SUMMARY,
} from "../trust-copy";
import { WEB_MARKETING_PROMISE } from "../site/web-marketing-copy";
import {
  MARKETING_SITE_URL,
  resolveMarketingSiteUrl,
} from "../site/marketing-site";

export function runConsumerBrandAuditTests(root = process.cwd()): { failures: string[] } {
  const failures: string[] = [];

  const check = (name: string, fn: () => void) => {
    try {
      fn();
    } catch (err) {
      failures.push(`${name}: ${err instanceof Error ? err.message : String(err)}`);
    }
  };

  check("consumer copy files avoid banned brand/provider strings", () => {
    for (const rel of CONSUMER_COPY_SCAN_FILES) {
      const full = join(root, rel);
      const source = readFileSync(full, "utf8");
      const violations = scanConsumerCopyFile(rel, source);
      if (violations.length > 0) {
        throw new Error(violations.join("\n"));
      }
    }
  });

  check("privacy copy contains AI transcription/analysis disclosure", () => {
    const privacyText = [
      AI_TRANSCRIPTION_ANALYSIS_SUMMARY,
      ...PRIVACY_SECTIONS.map((s) => `${s.title} ${s.body}`),
      PROCESSING_PROVIDERS_SUMMARY,
    ].join(" ");
    if (!/AI transcription and analysis/i.test(privacyText)) {
      throw new Error("missing AI transcription and analysis section");
    }
    for (const marker of PRIVACY_AI_DISCLOSURE_MARKERS) {
      if (!privacyText.toLowerCase().includes(marker.toLowerCase())) {
        throw new Error(`missing privacy marker: ${marker}`);
      }
    }
  });

  check("privacy copy does not headline OpenAI or ChatGPT", () => {
    for (const section of PRIVACY_SECTIONS) {
      if (/openai|chatgpt|whisper/i.test(section.title)) {
        throw new Error(`provider-branded section title: ${section.title}`);
      }
    }
  });

  check("site header uses ArchiveMe brand and AM logo initials", () => {
    const header = readFileSync(join(root, "apps/web/components/SiteHeader.tsx"), "utf8");
    const brand = readFileSync(join(root, "packages/shared/lib/product/brand-copy.ts"), "utf8");
    if (!header.includes("APP_BRAND_NAME")) {
      throw new Error("SiteHeader missing APP_BRAND_NAME");
    }
    if (!header.includes("APP_LOGO_INITIALS")) {
      throw new Error("SiteHeader missing APP_LOGO_INITIALS");
    }
    if (!brand.includes('"ArchiveMe"')) {
      throw new Error("brand-copy missing ArchiveMe");
    }
    if (!brand.includes('"AM"')) {
      throw new Error("brand-copy missing AM logo initials");
    }
    if (/\bVoiceMemory\b/.test(header)) {
      throw new Error("SiteHeader still contains VoiceMemory");
    }
  });

  check("marketing homepage uses canonical promise", () => {
    const page = readFileSync(join(root, "apps/web/app/page.tsx"), "utf8");
    if (!page.includes("WEB_MARKETING_PROMISE")) {
      throw new Error("homepage missing WEB_MARKETING_PROMISE");
    }
    if (WEB_MARKETING_PROMISE !== "Save the moment. See what returns.") {
      throw new Error("unexpected marketing promise");
    }
  });

  check("marketing site defaults to archiveme.app", () => {
    if (MARKETING_SITE_URL !== "https://archiveme.app") {
      throw new Error(`unexpected MARKETING_SITE_URL: ${MARKETING_SITE_URL}`);
    }
    if (resolveMarketingSiteUrl({}) !== "https://archiveme.app") {
      throw new Error("resolveMarketingSiteUrl default should be archiveme.app");
    }
  });

  check("trust pages use ArchiveMe and canonical contact email", () => {
    for (const rel of [
      "apps/web/app/privacy/page.tsx",
      "apps/web/app/terms/page.tsx",
      "apps/web/app/safety/page.tsx",
      "apps/web/app/contact/page.tsx",
    ]) {
      const src = readFileSync(join(root, rel), "utf8");
      if (/VoiceMemory|voice memory/i.test(src)) {
        throw new Error(`legacy brand in ${rel}`);
      }
      if (!/ArchiveMe/.test(src)) {
        throw new Error(`ArchiveMe missing from ${rel} metadata`);
      }
    }
    if (CONTACT_EMAIL !== "hello@archiveme.app") {
      throw new Error(`unexpected CONTACT_EMAIL: ${CONTACT_EMAIL}`);
    }
  });

  check("allowlist documents internal-only paths and literal exceptions", () => {
    if (CONSUMER_BRAND_ALLOWLIST_PATHS.length < 5) {
      throw new Error("allowlist too short");
    }
    if (!CONSUMER_BRAND_LITERAL_ALLOWLIST["hello@archiveme.app"]) {
      throw new Error("contact email allowlist missing hello@archiveme.app");
    }
  });

  check("banned pattern lists cover brand and customer vocabulary", () => {
    const brandLabels = CONSUMER_BANNED_PATTERNS.map((p) => p.label);
    for (const required of ["ChatGPT", "VoiceMemory", "OpenAI processing"]) {
      if (!brandLabels.includes(required)) {
        throw new Error(`missing banned label: ${required}`);
      }
    }
    const vocabLabels = CUSTOMER_LANGUAGE_BANNED_PATTERNS.map((p) => p.label);
    for (const required of ["belief", "proof", "theory", "blind spot"]) {
      if (!vocabLabels.includes(required)) {
        throw new Error(`missing vocabulary ban: ${required}`);
      }
    }
  });

  return { failures };
}
