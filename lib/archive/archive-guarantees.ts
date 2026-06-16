import { inspectArchivePackageIntegrity } from "@/lib/reliability/archive-integrity";
import { getAllEntries } from "@/lib/storage";
import type { JournalEntry } from "@/types/journal";
import type {
  ArchiveGuaranteeReport,
  ArchivePermanenceManifest,
} from "@/types/archive-permanence-layer";
import type { ArchiveMeArchivePackage } from "@/types/archive-permanence";
import { buildFutureContinuityReport } from "@/lib/archive/future-continuity";

export const ARCHIVE_SCHEMA_VERSION = 1;
export const ARCHIVE_MANIFEST_VERSION = 1;

function hashString(input: string): string {
  let hash = 5381;
  for (let i = 0; i < input.length; i += 1) {
    hash = (hash * 33) ^ input.charCodeAt(i);
  }
  return (hash >>> 0).toString(16).padStart(8, "0");
}

function entryFingerprint(entries: JournalEntry[]): string {
  const payload = entries
    .map((e) => `${e.id}:${e.createdAt.slice(0, 10)}`)
    .sort()
    .join("|");
  return hashString(payload);
}

function callbackFingerprint(entries: JournalEntry[]): string {
  const continuity = buildFutureContinuityReport(entries);
  return hashString(continuity.stableCallbackIds.join("|"));
}

/** Build portable archive manifest with integrity hashes. */
export function buildArchivePermanenceManifest(
  pkg: Pick<ArchiveMeArchivePackage, "entries" | "exportedAt" | "audio">,
): ArchivePermanenceManifest {
  const entryCount = pkg.entries.length;
  const audioReferenceCount = pkg.audio?.length ?? pkg.entries.filter((e) => e.audioId).length;

  const integrityPayload = [
    pkg.exportedAt,
    String(entryCount),
    entryFingerprint(pkg.entries),
    callbackFingerprint(pkg.entries),
    String(audioReferenceCount),
  ].join(":");

  return {
    schemaVersion: ARCHIVE_SCHEMA_VERSION,
    archiveVersion: ARCHIVE_MANIFEST_VERSION,
    exportedAt: pkg.exportedAt,
    entryCount,
    callbackFingerprint: callbackFingerprint(pkg.entries),
    integrityHash: hashString(integrityPayload),
    audioReferenceCount,
    forwardCompatible: true,
  };
}

function restorationIssues(pkg: ArchiveMeArchivePackage): ArchiveGuaranteeReport["issues"] {
  const issues: ArchiveGuaranteeReport["issues"] = [];
  const integrityIssues = inspectArchivePackageIntegrity(pkg);

  for (const issue of integrityIssues) {
    issues.push({
      level:
        issue.type.includes("invalid") || issue.type.includes("corrupted") ? "error" : "warning",
      message: issue.detail,
    });
  }

  const audioIds = new Set((pkg.audio ?? []).map((a) => a.entryId));
  for (const entry of pkg.entries) {
    if (entry.audioId && !audioIds.has(entry.id) && (pkg.audio?.length ?? 0) > 0) {
      issues.push({
        level: "warning",
        message: `Entry ${entry.id} references audio not included in export bundle`,
      });
    }
  }

  if (pkg.version !== ARCHIVE_SCHEMA_VERSION) {
    issues.push({
      level: "warning",
      message: `Archive version ${pkg.version} may need migration to ${ARCHIVE_SCHEMA_VERSION}`,
    });
  }

  return issues;
}

export function checkRestorationCompatibility(pkg: ArchiveMeArchivePackage): boolean {
  const issues = restorationIssues(pkg);
  return !issues.some((i) => i.level === "error");
}

export function buildArchiveGuaranteeReport(
  pkg?: ArchiveMeArchivePackage,
): ArchiveGuaranteeReport {
  const archive =
    pkg ??
    ({
      format: "voicememory-archive",
      version: 1,
      exportedAt: new Date().toISOString(),
      entries: getAllEntries(),
      bookmarks: [],
      settings: {
        reminders: {
          dailyReflection: true,
          afterStressfulEntry: true,
          weeklyReview: true,
          inactiveThreeDays: true,
          preferredReflectionHour: 20,
        },
        reflectionGoal: "off",
        listeningMode: false,
        fullDetail: false,
      },
      memoryReviewLabels: [],
    } satisfies ArchiveMeArchivePackage);

  const manifest = buildArchivePermanenceManifest(archive);
  const issues = restorationIssues(archive);
  const restorationCompatible = checkRestorationCompatibility(archive);

  const exportLongevityScore = Math.min(
    100,
    Math.round(
      (restorationCompatible ? 40 : 10) +
        Math.min(archive.entries.length, 30) +
        (manifest.audioReferenceCount > 0 ? 15 : 5) +
        (manifest.forwardCompatible ? 20 : 0) -
        issues.filter((i) => i.level === "error").length * 20,
    ),
  );

  return {
    generatedAt: new Date().toISOString(),
    hasData: archive.entries.length > 0,
    manifest,
    restorationCompatible,
    schemaEvolutionSafe: manifest.forwardCompatible && archive.version === ARCHIVE_SCHEMA_VERSION,
    exportLongevityScore,
    issues,
  };
}

export function attachPermanenceManifest(
  pkg: ArchiveMeArchivePackage,
): ArchiveMeArchivePackage & { permanenceManifest: ArchivePermanenceManifest } {
  return {
    ...pkg,
    permanenceManifest: buildArchivePermanenceManifest(pkg),
  };
}

export function verifyManifestIntegrity(
  pkg: ArchiveMeArchivePackage & { permanenceManifest?: ArchivePermanenceManifest },
): boolean {
  if (!pkg.permanenceManifest) return false;
  const rebuilt = buildArchivePermanenceManifest(pkg);
  return rebuilt.integrityHash === pkg.permanenceManifest.integrityHash;
}
