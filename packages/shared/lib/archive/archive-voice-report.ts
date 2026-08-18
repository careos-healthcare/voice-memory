import fs from "node:fs";
import path from "node:path";

import {
  findPreferredSignalsInSource,
  scanArchiveVoiceSource,
} from "@/lib/archive/archive-voice";
import {
  ARCHIVE_VOICE_SCOPES,
  collectArchiveVoiceScopeFiles,
} from "@/lib/archive/archive-voice-scopes";
import type { ArchiveVoiceConsistencyReport } from "@/types/archive-voice";

export function buildArchiveVoiceConsistencyReport(
  root = process.cwd(),
): ArchiveVoiceConsistencyReport {
  const scopes = ARCHIVE_VOICE_SCOPES.map((scope) => {
    const files = collectArchiveVoiceScopeFiles(root, scope);
    const violations = [];
    const preferredSet = new Set<string>();

    for (const file of files) {
      const abs = path.join(root, file);
      let source = "";
      try {
        source = fs.readFileSync(abs, "utf8");
      } catch {
        continue;
      }
      violations.push(...scanArchiveVoiceSource(source, file));
      for (const signal of findPreferredSignalsInSource(source)) {
        preferredSet.add(signal);
      }
    }

    return {
      id: scope.id,
      label: scope.label,
      filesScanned: files.length,
      violations,
      preferredSignalsFound: [...preferredSet],
    };
  });

  const totalViolations = scopes.reduce((n, s) => n + s.violations.length, 0);
  const pass = totalViolations === 0;

  const summaryLines: string[] = [
    pass
      ? "All scanned intelligence surfaces pass archive voice rules."
      : `${totalViolations} violation(s) — coaching, motivational, or therapy language detected.`,
  ];

  for (const scope of scopes) {
    if (scope.violations.length > 0) {
      summaryLines.push(
        `${scope.label}: ${scope.violations.length} issue(s) across ${scope.filesScanned} files.`,
      );
    } else if (scope.preferredSignalsFound.length === 0) {
      summaryLines.push(
        `${scope.label}: no violations, but weak preferred-signal coverage (${scope.filesScanned} files).`,
      );
    } else {
      summaryLines.push(
        `${scope.label}: clean (${scope.preferredSignalsFound.length} archive-voice signal(s)).`,
      );
    }
  }

  return {
    title: "Archive Voice Consistency",
    generatedAt: new Date().toISOString(),
    pass,
    scopes,
    totalViolations,
    summaryLines,
  };
}
