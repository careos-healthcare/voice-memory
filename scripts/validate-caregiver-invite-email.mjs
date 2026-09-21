#!/usr/bin/env node
import { runCaregiverInviteEmailTests } from "../apps/api/src/services/caregiver/attempt-caregiver-invite-email-tests.ts";

const failures = [...(await runCaregiverInviteEmailTests()).failures];

if (failures.length) {
  console.error("validate-caregiver-invite-email failed:\n", failures.join("\n"));
  process.exit(1);
}
console.log("validate-caregiver-invite-email ok");
