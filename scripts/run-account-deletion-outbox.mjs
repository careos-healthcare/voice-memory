#!/usr/bin/env node
import { processPendingAccountDeletionOutbox } from "../lib/server/account-deletion.ts";

const result = await processPendingAccountDeletionOutbox();
console.log(JSON.stringify({ task: "account-deletion-outbox", ...result }));
