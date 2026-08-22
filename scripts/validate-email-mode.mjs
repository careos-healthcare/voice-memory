#!/usr/bin/env node
import { getEmailMode, isEmailDisabled } from "../packages/shared/lib/server/email-mode.ts";

const failures = [];

if (process.env.NODE_ENV === "production" && !isEmailDisabled()) {
  if (!process.env.RESEND_API_KEY?.trim()) failures.push("RESEND_API_KEY required when EMAIL_DISABLED is not true");
  if (!process.env.EMAIL_FROM?.trim()) failures.push("EMAIL_FROM required when email enabled");
}

const mode = getEmailMode();
if (mode === "unconfigured" && process.env.VOICEMEMORY_GRADE_A_STRICT === "1") {
  failures.push("email mode unconfigured under strict validation");
}

if (failures.length) {
  console.error("validate-email-mode failed:\n", failures.join("\n"));
  process.exit(1);
}
console.log(`validate-email-mode ok (mode=${mode})`);
