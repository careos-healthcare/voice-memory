import { unzipSync } from "fflate";

import { parseArchiveJson } from "@/lib/archive/validate-import";
import type { VoiceMemoryArchivePackage } from "@/types/archive-permanence";

function bytesToText(bytes: Uint8Array): string {
  return new TextDecoder().decode(bytes);
}

export function unzipArchivePackage(buffer: ArrayBuffer): VoiceMemoryArchivePackage | null {
  try {
    const files = unzipSync(new Uint8Array(buffer));
    const archiveBytes = files["archive.json"];
    if (archiveBytes) {
      return parseArchiveJson(JSON.parse(bytesToText(archiveBytes)) as unknown);
    }

    const jsonCandidates = Object.entries(files).filter(([name]) => name.endsWith(".json"));
    for (const [, bytes] of jsonCandidates) {
      const parsed = parseArchiveJson(JSON.parse(bytesToText(bytes)) as unknown);
      if (parsed) return parsed;
    }

    return null;
  } catch {
    return null;
  }
}
