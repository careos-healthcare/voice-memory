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

export async function unsubscribeWaitlist(input: {
  token?: string;
  email?: string;
}): Promise<boolean> {
  const token = input.token?.trim() ?? "";
  const email = input.email?.trim().toLowerCase() ?? "";
  if (!token && !email) return false;
  const updated = await dbQuery(
    `UPDATE waitlist_signups
     SET unsubscribed_at = now()
     WHERE unsubscribed_at IS NULL
       AND (
         ($1 <> '' AND unsubscribe_token = $1)
         OR ($2 <> '' AND email = $2)
       )`,
    [token, email],
  );
  return (updated.rowCount ?? 0) > 0;
}
