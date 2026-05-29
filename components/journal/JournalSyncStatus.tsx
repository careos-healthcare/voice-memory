"use client";

import { SyncStatus } from "@/components/system/SyncStatus";

/** Journal archive sync — visible status with retry when needed. */
export function JournalSyncStatus() {
  return <SyncStatus className="mt-1" />;
}
