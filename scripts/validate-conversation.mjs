#!/usr/bin/env node
import { runConversationTests } from "../apps/api/src/services/insights/conversation-tests.ts";

const failures = [...(await runConversationTests()).failures];

if (failures.length) {
  console.error("validate-conversation failed:\n", failures.join("\n"));
  process.exit(1);
}
console.log("validate-conversation ok");
