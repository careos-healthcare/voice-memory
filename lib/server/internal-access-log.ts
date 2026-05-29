import "server-only";

import { createHash } from "node:crypto";

export interface InternalAccessLogEntry {
  at: string;
  pathname: string;
  method: string;
  outcome: "allowed" | "denied";
  detail: string;
  ipHash: string;
}

const globalLog = globalThis as typeof globalThis & {
  __vmInternalAccessLog?: InternalAccessLogEntry[];
};

const MAX_ENTRIES = 200;

function hashIp(ip: string): string {
  return createHash("sha256").update(ip).digest("hex").slice(0, 16);
}

export async function logInternalAccessEvent(input: {
  pathname: string;
  method: string;
  outcome: "allowed" | "denied";
  detail: string;
  ipHash: string;
}): Promise<void> {
  const entry: InternalAccessLogEntry = {
    at: new Date().toISOString(),
    pathname: input.pathname,
    method: input.method,
    outcome: input.outcome,
    detail: input.detail,
    ipHash: input.ipHash.length > 20 ? hashIp(input.ipHash) : input.ipHash,
  };

  if (!globalLog.__vmInternalAccessLog) {
    globalLog.__vmInternalAccessLog = [];
  }
  const buf = globalLog.__vmInternalAccessLog;
  buf.push(entry);
  if (buf.length > MAX_ENTRIES) {
    buf.splice(0, buf.length - MAX_ENTRIES);
  }

  if (process.env.NODE_ENV === "development") {
    console.info(
      `[internal-access] ${entry.outcome} ${entry.method} ${entry.pathname} (${entry.detail})`,
    );
  }
}

export function readInternalAccessLog(): InternalAccessLogEntry[] {
  return [...(globalLog.__vmInternalAccessLog ?? [])];
}
