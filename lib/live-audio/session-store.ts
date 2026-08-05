const globalStore = globalThis as typeof globalThis & {
  __vmLiveAudioSessions?: Map<
    string,
    {
      sessionId: string;
      subject: string;
      ipHash: string;
      uaHash: string;
      createdAt: number;
      consumed: boolean;
    }
  >;
};

function store(): Map<
  string,
  {
    sessionId: string;
    subject: string;
    ipHash: string;
    uaHash: string;
    createdAt: number;
    consumed: boolean;
  }
> {
  if (!globalStore.__vmLiveAudioSessions) {
    globalStore.__vmLiveAudioSessions = new Map();
  }
  return globalStore.__vmLiveAudioSessions;
}

export async function registerLiveAudioSession(input: {
  jti: string;
  sessionId: string;
  subject: string;
  ipHash: string;
  uaHash: string;
}): Promise<void> {
  store().set(input.jti, {
    sessionId: input.sessionId,
    subject: input.subject,
    ipHash: input.ipHash,
    uaHash: input.uaHash,
    createdAt: Date.now(),
    consumed: false,
  });
}

export async function consumeLiveAudioSession(input: {
  jti: string;
  ipHash: string;
  uaHash: string;
}): Promise<
  | { ok: true; sessionId: string; subject: string }
  | { ok: false; reason: "missing" | "consumed" | "binding_mismatch" }
> {
  const row = store().get(input.jti);
  if (!row) return { ok: false, reason: "missing" };
  if (row.consumed) return { ok: false, reason: "consumed" };
  if (row.ipHash !== input.ipHash || row.uaHash !== input.uaHash) {
    return { ok: false, reason: "binding_mismatch" };
  }
  row.consumed = true;
  return { ok: true, sessionId: row.sessionId, subject: row.subject };
}

export function resetLiveAudioSessionStoreForTest(): void {
  store().clear();
}

/**
 * Removes every registered live-audio session for a subject (e.g.
 * `user:<id>`, matching `ApiGuardContext.subject`). Ephemeral/in-memory
 * only, but included in the account-deletion contract for audit
 * completeness. Idempotent.
 */
export function deleteLiveAudioSessionsForSubject(subject: string): number {
  let removed = 0;
  for (const [jti, row] of store()) {
    if (row.subject === subject) {
      store().delete(jti);
      removed += 1;
    }
  }
  return removed;
}
