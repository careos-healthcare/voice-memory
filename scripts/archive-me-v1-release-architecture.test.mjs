import assert from "node:assert/strict";
import path from "node:path";
import test from "node:test";
import { fileURLToPath } from "node:url";

import {
  CLASSIFICATIONS,
  buildArchitectureReport,
  renderReachabilityMarkdown,
  renderRemovalManifest,
} from "./archive-me-v1-release-architecture.mjs";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");

test("V1 release contract matches the repository architecture", async () => {
  const report = await buildArchitectureReport(root);

  assert.deepEqual(report.violations, []);
  assert.equal(report.status, "PASS");
  assert.deepEqual(report.routes.allowlist.primary, [
    "/record",
    "/archive-belief",
    "/belief-changes",
    "/account",
  ]);
  assert.equal(report.entryPoints.configured.length, 1);
  assert.ok(report.entryPoints.reachableDartFiles.includes(
    "apps/voicememory_mobile/lib/router/app_router.dart",
  ));
});

test("all major module dispositions are represented once", async () => {
  const report = await buildArchitectureReport(root);
  const actual = report.modules.map((row) => row.classification).sort();

  assert.deepEqual(actual, [...CLASSIFICATIONS].sort());
  assert.equal(new Set(report.modules.flatMap((row) => row.modules)).size,
    report.modules.flatMap((row) => row.modules).length);
});

test("every production Dart file has an import-graph disposition", async () => {
  const report = await buildArchitectureReport(root);
  const inventory = report.reachabilityInventory;

  assert.equal(
    inventory.productionDartFileCount,
    inventory.shippingReachable.count +
      inventory.testOnly.count +
      inventory.dormantUnreachable.count,
  );
  assert.deepEqual(inventory.testGraphUnresolvedLocalImports, []);
  assert.ok(inventory.testOnly.files.every(
    (file) => !inventory.shippingReachable.files.includes(file),
  ));
  assert.ok(inventory.dormantUnreachable.files.every(
    (file) =>
      !inventory.shippingReachable.files.includes(file) &&
      !inventory.testOnly.files.includes(file),
  ));
});

test("removed module boundaries remain outside every Dart graph", async () => {
  const report = await buildArchitectureReport(root);
  const removed = report.modules.find(
    (row) => row.classification === "REMOVE",
  );

  for (const disposition of removed.dispositions) {
    assert.equal(disposition.shippingReachableFiles, 0);
    assert.equal(disposition.testOnlyFiles, 0);
    assert.equal(disposition.dormantUnreachableFiles, 0);
  }
});

test("API-only backend has no consumer pages and preserves experiment support", async () => {
  const report = await buildArchitectureReport(root);

  assert.deepEqual(report.webSurface.consumerPageFiles, []);
  assert.deepEqual(report.webSurface.clientClassifications, [
    {
      file: "app/archive/ArchivePageClient.tsx",
      classification: "EXPERIMENTAL_SUPPORT",
    },
    {
      file: "app/pricing/PricingPageClient.tsx",
      classification: "EXPERIMENTAL_SUPPORT",
    },
  ]);
});

test("generated human reports are deterministic contract views", async () => {
  const report = await buildArchitectureReport(root);
  const reachability = renderReachabilityMarkdown(report);
  const removal = renderRemovalManifest(report);

  assert.match(reachability, /Four primary destinations/);
  assert.match(reachability, /Production Dart disposition/);
  assert.match(reachability, /Dormant, unreachable production files/);
  assert.match(reachability, /node scripts\/archive-me-v1-release-architecture\.mjs --check/);
  for (const classification of CLASSIFICATIONS) {
    assert.match(removal, new RegExp(`## ${classification}`));
  }
});
