#!/usr/bin/env node
/**
 * Account-deletion contract tests. Several modules under test (account
 * deletion, sync store, auth storage, mobile push devices, data-path) are
 * guarded with `import "server-only"`, which throws under plain Node/tsx
 * unless the `react-server` export condition is active — hence this script
 * must be invoked with `node --conditions=react-server` (see the
 * `validate:account-deletion` npm script).
 */
import { runAccountDeletionTests } from "../lib/reliability/account-deletion-tests.ts";

const { failures } = await runAccountDeletionTests();

if (failures.length > 0) {
  console.error("account-deletion-tests failed:\n", failures.join("\n"));
  process.exit(1);
}
console.log("account-deletion-tests ok");
