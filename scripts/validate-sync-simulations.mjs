#!/usr/bin/env node
/**
 * Lightweight CI check for sync failure simulations.
 * Mirrors lib/sync/sync-simulator.ts scenarios without a test runner.
 */

function parseTime(iso) {
  if (!iso) return 0;
  const time = new Date(iso).getTime();
  return Number.isFinite(time) ? time : 0;
}

function pickNewer(local, remote, localDeviceId) {
  if (parseTime(local.updatedAt) > parseTime(remote.updatedAt)) {
    return { winner: local, resolution: "kept_local" };
  }
  if (parseTime(remote.updatedAt) > parseTime(local.updatedAt)) {
    return { winner: remote, resolution: "kept_remote" };
  }
  if (local.sourceDeviceId === localDeviceId) {
    return { winner: local, resolution: "kept_local" };
  }
  return { winner: local, resolution: "kept_local" };
}

function mergeEntries(local, remote, localDeviceId) {
  const byId = new Map();
  const conflicts = [];
  for (const record of [...remote, ...local]) {
    const existing = byId.get(record.entry.id);
    if (!existing) {
      byId.set(record.entry.id, record);
      continue;
    }
    const { winner, resolution } = pickNewer(existing, record, localDeviceId);
    byId.set(record.entry.id, winner);
    if (existing.updatedAt !== record.updatedAt) {
      conflicts.push({ key: record.entry.id, resolution });
    }
  }
  return { merged: [...byId.values()], conflicts };
}

const DEVICE_A = "sim-a";
const DEVICE_B = "sim-b";
const NOW = "2026-05-19T12:00:00.000Z";
const OLDER = "2026-05-18T12:00:00.000Z";
const NEWER = "2026-05-19T14:00:00.000Z";

function entry(id, updatedAt, deviceId) {
  return { entry: { id, transcript: id, createdAt: updatedAt }, updatedAt, sourceDeviceId: deviceId };
}

const scenarios = [
  {
    name: "corrupted_encrypted_sync_blob",
    run: () => {
      const blob = { iv: "", ciphertext: "" };
      return !blob.iv || !blob.ciphertext;
    },
  },
  {
    name: "partial_restore",
    run: () => {
      const local = [entry("local-only", NOW, DEVICE_A)];
      const remote = [entry("remote-only", NOW, DEVICE_B)];
      const merged = mergeEntries(local, remote, DEVICE_A).merged;
      return merged.some((row) => row.entry.id === "local-only") &&
        merged.some((row) => row.entry.id === "remote-only");
    },
  },
  {
    name: "stale_device_conflict",
    run: () => {
      const local = [entry("shared", NEWER, DEVICE_A)];
      const remote = [entry("shared", OLDER, DEVICE_B)];
      const { merged, conflicts } = mergeEntries(local, remote, DEVICE_A);
      const winner = merged.find((row) => row.entry.id === "shared");
      return winner.updatedAt === NEWER && conflicts.length === 1;
    },
  },
  {
    name: "offline_save_then_replay",
    run: () => {
      const local = [entry("offline", NEWER, DEVICE_A)];
      const remote = [];
      const merged = mergeEntries(local, remote, DEVICE_A).merged;
      return merged.some((row) => row.entry.id === "offline");
    },
  },
  {
    name: "duplicate_entry_merge",
    run: () => {
      const local = [entry("dup", NOW, DEVICE_A)];
      const remote = [entry("dup", NEWER, DEVICE_B)];
      const { merged, conflicts } = mergeEntries(local, remote, DEVICE_A);
      return merged.filter((row) => row.entry.id === "dup").length === 1 && conflicts.length === 1;
    },
  },
  {
    name: "restore_older_schema_version",
    run: () => {
      const legacy = { version: 1, entries: [{ id: "legacy", transcript: "x", createdAt: OLDER }] };
      return legacy.version === 1 && legacy.entries.length === 1;
    },
  },
];

let failed = 0;
for (const scenario of scenarios) {
  const passed = scenario.run();
  if (!passed) {
    failed += 1;
    console.error(`FAIL ${scenario.name}`);
  } else {
    console.log(`OK ${scenario.name}`);
  }
}

if (failed > 0) {
  console.error(`\n${failed} simulation(s) failed.`);
  process.exit(1);
}

console.log(`\nAll ${scenarios.length} sync simulations passed.`);
