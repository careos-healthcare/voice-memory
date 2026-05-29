#!/usr/bin/env node
import { validateProductionEnv, formatProductionEnvReport } from "../lib/server/production-env.ts";

const strict =
  process.argv.includes("--strict") ||
  process.env.VOICEMEMORY_GRADE_A_STRICT === "1" ||
  process.env.NODE_ENV === "production";

const report = validateProductionEnv({ strict });

for (const issue of report.issues) {
  const line = `[${issue.level}] ${issue.code}: ${issue.message}`;
  if (issue.level === "error") console.error(line);
  else console.warn(line);
}

if (!report.ok) {
  if (strict) {
    console.error("\nvalidate-production-env FAILED (strict)\n");
    console.error(formatProductionEnvReport(report));
    process.exit(1);
  }
  console.warn("\nvalidate-production-env: errors present (development — not failing)\n");
} else {
  console.log("validate-production-env ok");
}
