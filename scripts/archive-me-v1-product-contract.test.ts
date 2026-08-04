import assert from "node:assert/strict";
import test from "node:test";

import {
  archiveMeV1ProductContract,
  archiveMeV1StartupTier,
  isArchiveMeV1ConsumerRouteAllowed,
} from "../lib/product/archive-me-v1-product-contract";

test("commercial V1 exposes exactly four primary destinations", () => {
  assert.deepEqual(archiveMeV1ProductContract.primaryRoutes, [
    "/record",
    "/archive-belief",
    "/belief-changes",
    "/account",
  ]);
});

test("consumer navigation admits focused routes and rejects experiments", () => {
  for (const route of [
    "/record",
    "/quick-capture",
    "/archive-belief",
    "/belief-changes",
    "/account",
    "/entry/entry-1",
  ]) {
    assert.equal(isArchiveMeV1ConsumerRouteAllowed(route), true, route);
  }
  for (const route of [
    "/life-os",
    "/life-os/graph",
    "/archive-tools",
    "/self-discovery",
    "/blind-spots",
    "/live-voice",
  ]) {
    assert.equal(isArchiveMeV1ConsumerRouteAllowed(route), false, route);
  }
});

test("startup service tiers keep experiments outside focused startup", () => {
  assert.equal(
    archiveMeV1StartupTier("SensitiveTemporaryAudioStore"),
    "required",
  );
  assert.equal(archiveMeV1StartupTier("RecordingService"), "onDemand");
  assert.equal(
    archiveMeV1StartupTier("LocalLlamaReconciliation"),
    "excluded",
  );
  assert.equal(archiveMeV1StartupTier("GraphExplorer"), "excluded");
});

test("removed capability groups remain prohibited", () => {
  for (const capability of [
    "healthkit",
    "health_connect",
    "location",
    "bluetooth_product_integration",
    "graph_database",
    "graph_sync",
    "peer_to_peer_sync",
  ]) {
    assert.ok(
      archiveMeV1ProductContract.prohibitedCapabilityGroups.includes(
        capability,
      ),
      capability,
    );
  }
});
