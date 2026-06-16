import { readFileSync } from "node:fs";
import { join } from "node:path";

import {
  CONSUMER_BANNED_PATTERNS,
  CONSUMER_BRAND_ALLOWLIST_PATHS,
  CONSUMER_BRAND_LITERAL_ALLOWLIST,
  CONSUMER_COPY_SCAN_FILES,
  PRIVACY_AI_DISCLOSURE_MARKERS,
  scanConsumerCopyFile,
} from "@/lib/reliability/consumer-brand-audit";
import {
  AI_TRANSCRIPTION_ANALYSIS_SUMMARY,
  PRIVACY_SECTIONS,
  PROCESSING_PROVIDERS_SUMMARY,
} from "@/lib/trust-copy";

export function runConsumerBrandAuditTests(): { failures: string[] } {
  const failures: string[] = [];
  const root = process.cwd();

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

  check("site header shell uses ArchiveMe brand and AM logo initials", () => {
    const header = readFileSync(join(root, "components/SiteHeader.tsx"), "utf8");
    const brand = readFileSync(join(root, "lib/product/brand-copy.ts"), "utf8");
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
    if (/>\s*VM\s*</.test(header)) {
      throw new Error("SiteHeader still renders VM logo initials");
    }
  });

  check("trust page metadata uses ArchiveMe not VoiceMemory", () => {
    for (const rel of [
      "app/privacy/page.tsx",
      "app/terms/page.tsx",
      "app/safety/page.tsx",
      "app/contact/page.tsx",
    ]) {
      const src = readFileSync(join(root, rel), "utf8");
      if (/VoiceMemory|voice memory/i.test(src)) {
        throw new Error(`legacy brand in ${rel}`);
      }
      if (!/ArchiveMe/.test(src)) {
        throw new Error(`ArchiveMe missing from ${rel} metadata`);
      }
    }
  });

  check("landing metadata uses ArchiveMe not VoiceMemory", () => {
    const layout = readFileSync(join(root, "app/layout.tsx"), "utf8");
    const manifest = readFileSync(join(root, "app/manifest.ts"), "utf8");
    for (const src of [layout, manifest]) {
      if (/VoiceMemory|voice memory|ChatGPT|OpenAI processing/i.test(src)) {
        throw new Error("legacy brand/provider in landing metadata");
      }
      if (!/ArchiveMe/.test(src)) {
        throw new Error("ArchiveMe missing from landing metadata");
      }
    }
  });

  check("allowlist documents internal-only paths and literal exceptions", () => {
    if (CONSUMER_BRAND_ALLOWLIST_PATHS.length < 5) {
      throw new Error("allowlist too short");
    }
    if (!CONSUMER_BRAND_LITERAL_ALLOWLIST["hello@voicememory.app"]) {
      throw new Error("contact email allowlist missing");
    }
    for (const path of CONSUMER_BRAND_ALLOWLIST_PATHS) {
      if (!path.includes("/") && !path.endsWith(".ts")) {
        throw new Error(`unexpected allowlist entry: ${path}`);
      }
    }
  });

  check("banned pattern list covers ChatGPT and VoiceMemory", () => {
    const labels = CONSUMER_BANNED_PATTERNS.map((p) => p.label);
    for (const required of ["ChatGPT", "VoiceMemory", "OpenAI processing"]) {
      if (!labels.includes(required)) {
        throw new Error(`missing banned label: ${required}`);
      }
    }
  });

  return { failures };
}
