import { dbQuery } from "@/lib/server/db";
import type { WaitlistInsertResult, WaitlistStore } from "@/lib/waitlist/signup";

export const postgresWaitlistStore: WaitlistStore = {
  async insert(email, unsubscribeToken): Promise<WaitlistInsertResult> {
    const inserted = await dbQuery<{ inserted: boolean }>(
      `INSERT INTO waitlist_signups (email, unsubscribe_token)
       VALUES ($1, $2)
       ON CONFLICT (email) DO UPDATE SET unsubscribed_at = NULL
       RETURNING (xmax = 0) AS inserted`,
      [email, unsubscribeToken],
    );
    return inserted.rows[0]?.inserted ? "created" : "duplicate";
  },
};

export async function waitlistTokenMatchesEmail(token: string, email: string): Promise<boolean> {
  const found = await dbQuery<{ email: string }>(
    `SELECT email FROM waitlist_signups WHERE unsubscribe_token = $1`,
    [token],
  );
  const stored = found.rows[0]?.email;
  if (!stored) return false;
  return stored === email.trim().toLowerCase();
}

export async function unsubscribeWaitlist(input: {
  token?: string;
  email?: string;
}): Promise<boolean> {
  const token = input.token?.trim() ?? "";
  const email = input.email?.trim().toLowerCase() ?? "";
  if (!token) return false;
  const updated = await dbQuery(
    `UPDATE waitlist_signups
     SET unsubscribed_at = now()
     WHERE unsubscribed_at IS NULL
       AND unsubscribe_token = $1
       AND ($2 = '' OR email = $2)`,
    [token, email],
  );
  return (updated.rowCount ?? 0) > 0;
}

/** Five waitlist posts per IP per clock hour, stored in Postgres. */
export async function consumeWaitlistRateLimit(ip: string): Promise<boolean> {
  const updated = await dbQuery<{ request_count: number }>(
    `INSERT INTO rate_limits (subject_key, window_start, request_count)
     VALUES ($1, date_trunc('hour', now()), 1)
     ON CONFLICT (subject_key, window_start)
     DO UPDATE SET request_count = rate_limits.request_count + 1
     RETURNING request_count`,
    [`waitlist:${ip}`],
  );
  return (updated.rows[0]?.request_count ?? 6) <= 5;
}
