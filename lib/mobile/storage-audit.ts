const ESTIMATED_KEYS = [
  "voicememory_entries",
  "voicememory_open_loops",
  "voicememory_plan",
  "voicememory_monetization_observation",
];

export interface LocalStoragePressureReport {
  keyCount: number;
  estimatedBytes: number;
  sampledKeys: string[];
  pressure: "low" | "moderate" | "high";
}

export function auditLocalStoragePressure(): LocalStoragePressureReport {
  if (typeof window === "undefined") {
    return { keyCount: 0, estimatedBytes: 0, sampledKeys: [], pressure: "low" };
  }

  let estimatedBytes = 0;
  const sampledKeys: string[] = [];

  for (let i = 0; i < localStorage.length; i += 1) {
    const key = localStorage.key(i);
    if (!key) continue;
    const value = localStorage.getItem(key) ?? "";
    estimatedBytes += key.length + value.length * 2;
    if (ESTIMATED_KEYS.some((prefix) => key.startsWith(prefix)) || key.includes("voicememory")) {
      sampledKeys.push(key);
    }
  }

  const pressure =
    estimatedBytes > 4_500_000 ? "high" : estimatedBytes > 1_500_000 ? "moderate" : "low";

  return {
    keyCount: localStorage.length,
    estimatedBytes,
    sampledKeys: sampledKeys.slice(0, 24),
    pressure,
  };
}

export interface IndexedDbAudit {
  available: boolean;
  audioDbName: string;
  note: string;
}

export function auditIndexedDbUsage(): IndexedDbAudit {
  const available = typeof indexedDB !== "undefined";
  return {
    available,
    audioDbName: "voicememory_audio",
    note: available
      ? "Audio blobs stored in IndexedDB (recordings store). Photos/atmosphere may use separate DBs."
      : "IndexedDB unavailable — audio persistence will fail",
  };
}
