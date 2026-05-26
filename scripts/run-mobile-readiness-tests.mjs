#!/usr/bin/env node
import assert from "node:assert/strict";

import {
  isNativeWrapper,
  isPWA,
  supportsPush,
} from "../lib/mobile/platform.ts";
import { QUIET_NOTIFICATION_TRIGGERS } from "../lib/notifications/triggers.ts";
import { NOTIFICATION_COPY } from "../lib/notifications/notification-copy.ts";
import { buildQuietNotificationPayload } from "../lib/notifications/triggers.ts";

assert.equal(isNativeWrapper(), false);
assert.equal(isPWA(), false);

assert.equal(QUIET_NOTIFICATION_TRIGGERS.length, 3);
assert.ok(QUIET_NOTIFICATION_TRIGGERS.every((t) => t.minIntervalHours >= 48));

const payload = buildQuietNotificationPayload("open_loop_resurface");
assert.match(payload.title, /thread/i);
assert.ok(!payload.body.toLowerCase().includes("come back"));

for (const key of Object.keys(NOTIFICATION_COPY)) {
  const copy = NOTIFICATION_COPY[key];
  assert.ok(copy.title.length > 4);
  assert.ok(!copy.body.toLowerCase().includes("streak"));
}

console.log("All mobile readiness tests passed.");
