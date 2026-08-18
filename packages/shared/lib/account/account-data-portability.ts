import { buildArchiveExportAttachment } from "@/lib/archive/archive-export-attachment";
import { buildArchiveMarkdown } from "@/lib/archive/markdown-export";
import {
  buildArchiveSettingsSnapshot,
  buildFullArchivePackage,
} from "@/lib/archive/full-export";
import {
  buildExportJsonBundle,
  buildPrintableReport,
  slugExportDate,
} from "@/lib/memory-export";
import { EXPORT_TRUST_FOOTER } from "@/lib/product-copy";
import type { ArchiveMeArchivePackage } from "@/types/archive-permanence";
import type { JournalEntry } from "@/types/journal";

import {
  buildStoreOnlyZip,
  textToUtf8Bytes,
  type ZipEntryInput,
} from "./zip-store-writer";

export const ACCOUNT_PORTABILITY_FORMAT = "archiveme-account-portability";
export const ACCOUNT_PORTABILITY_VERSION = 1;

export interface AccountPortabilityManifest {
  format: typeof ACCOUNT_PORTABILITY_FORMAT;
  version: typeof ACCOUNT_PORTABILITY_VERSION;
  exportedAt: string;
  entryCount: number;
  includesAudio: boolean;
  includesPhotos: boolean;
  trustFooter: string;
  files: string[];
}

export interface AccountPortabilityBundle {
  manifest: AccountPortabilityManifest;
  json: Record<string, unknown>;
  markdown: string;
  printableReport?: ReturnType<typeof buildPrintableReport>;
}

export interface BuildAccountPortabilityOptions {
  dateFrom?: string;
  dateTo?: string;
  includeAudio?: boolean;
  includePhotos?: boolean;
  includePrintableReport?: boolean;
  maxReportExcerpts?: number;
}

function buildReadme(manifest: AccountPortabilityManifest): string {
  return [
    "# ArchiveMe Account Export",
    "",
    `Exported: ${manifest.exportedAt}`,
    `Entries: ${manifest.entryCount}`,
    "",
    EXPORT_TRUST_FOOTER,
    "",
    "## Files in this archive",
    "",
    "- `manifest.json` — export metadata",
    "- `archive.json` — structured JSON (entries + archive attachment)",
    "- `archive.md` — human-readable Markdown reflections",
    manifest.includesAudio ? "- `audio/` — optional audio attachments (when included)" : null,
    "- `print-report.json` — printable reflection report snapshot (when included)",
    "",
    "Store this ZIP where you trust. ArchiveMe does not upload exports to any server.",
    "",
  ]
    .filter(Boolean)
    .join("\n");
}

/** Builds the structured JSON + Markdown bundle used by web and mobile portability flows. */
export async function buildAccountPortabilityBundle(
  options: BuildAccountPortabilityOptions = {},
): Promise<AccountPortabilityBundle> {
  const {
    dateFrom = "",
    dateTo = "",
    includeAudio = false,
    includePhotos = false,
    includePrintableReport = true,
    maxReportExcerpts = 24,
  } = options;

  const exportBundle = buildExportJsonBundle(dateFrom, dateTo);
  const entries = exportBundle.entries;
  let fullArchive: ArchiveMeArchivePackage | null = null;

  if (dateFrom === "" && dateTo === "") {
    fullArchive = await buildFullArchivePackage(includeAudio, includePhotos);
  }

  const archiveAttachment =
    exportBundle.archiveAttachment ??
    (entries.length > 0 ? buildArchiveExportAttachment(entries) : undefined);

  const json: Record<string, unknown> = {
    format: ACCOUNT_PORTABILITY_FORMAT,
    version: ACCOUNT_PORTABILITY_VERSION,
    exportedAt: exportBundle.exportedAt,
    dateRange: exportBundle.dateRange,
    entryCount: exportBundle.entryCount,
    entries,
    archiveAttachment,
    fullArchive: fullArchive ?? undefined,
    trustFooter: EXPORT_TRUST_FOOTER,
  };

  const markdownSource: ArchiveMeArchivePackage =
    fullArchive ??
    ({
      format: "voicememory-archive",
      version: 1,
      exportedAt: exportBundle.exportedAt,
      entries: entries as JournalEntry[],
      bookmarks: [],
      settings: buildArchiveSettingsSnapshot(),
      memoryReviewLabels: [],
    } satisfies ArchiveMeArchivePackage);

  const markdown = buildArchiveMarkdown(markdownSource);
  const printableReport =
    includePrintableReport && entries.length > 0
      ? buildPrintableReport({
          dateFrom,
          dateTo,
          maxExcerpts: maxReportExcerpts,
        })
      : undefined;

  const manifest: AccountPortabilityManifest = {
    format: ACCOUNT_PORTABILITY_FORMAT,
    version: ACCOUNT_PORTABILITY_VERSION,
    exportedAt: exportBundle.exportedAt,
    entryCount: exportBundle.entryCount,
    includesAudio: includeAudio && Boolean(fullArchive?.audio?.length),
    includesPhotos: includePhotos && Boolean(fullArchive?.photos?.length),
    trustFooter: EXPORT_TRUST_FOOTER,
    files: [
      "README.md",
      "manifest.json",
      "archive.json",
      "archive.md",
      ...(printableReport ? ["print-report.json"] : []),
    ],
  };

  return {
    manifest,
    json,
    markdown,
    printableReport,
  };
}

export async function buildAccountPortabilityZipBytes(
  options: BuildAccountPortabilityOptions = {},
): Promise<Uint8Array> {
  const bundle = await buildAccountPortabilityBundle(options);
  const zipEntries: ZipEntryInput[] = [
    {
      path: "README.md",
      data: textToUtf8Bytes(buildReadme(bundle.manifest)),
    },
    {
      path: "manifest.json",
      data: textToUtf8Bytes(JSON.stringify(bundle.manifest, null, 2)),
    },
    {
      path: "archive.json",
      data: textToUtf8Bytes(JSON.stringify(bundle.json, null, 2)),
    },
    {
      path: "archive.md",
      data: textToUtf8Bytes(bundle.markdown),
    },
  ];

  if (bundle.printableReport) {
    zipEntries.push({
      path: "print-report.json",
      data: textToUtf8Bytes(JSON.stringify(bundle.printableReport, null, 2)),
    });
  }

  return buildStoreOnlyZip(zipEntries);
}

export function accountPortabilityZipFilename(): string {
  return `archiveme-account-export-${slugExportDate()}.zip`;
}

export function downloadAccountPortabilityZip(
  bytes: Uint8Array,
  filename = accountPortabilityZipFilename(),
): void {
  const blob = new Blob([bytes.slice()], { type: "application/zip" });
  const url = URL.createObjectURL(blob);
  const anchor = document.createElement("a");
  anchor.href = url;
  anchor.download = filename;
  anchor.click();
  URL.revokeObjectURL(url);
}

export async function downloadAccountPortabilityArchive(
  options: BuildAccountPortabilityOptions = {},
): Promise<void> {
  const bytes = await buildAccountPortabilityZipBytes(options);
  downloadAccountPortabilityZip(bytes);
}
