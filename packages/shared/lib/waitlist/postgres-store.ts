import { dbQuery } from "@/lib/server/db";
import type { WaitlistInsertResult, WaitlistStore } from "@/lib/waitlist/signup";

export const postgresWaitlistStore: WaitlistStore = {
  async insert(email, unsubscribeToken): Promise<WaitlistInsertResult> {
    const inserted = await dbQuery(
      `INSERT INTO waitlist_signups (email, unsubscribe_token)
       VALUES ($1, $2)
       ON CONFLICT (email) DO NOTHING`,
      [email, unsubscribeToken],
    );
    return (inserted.rowCount ?? 0) > 0 ? "created" : "duplicate";
  },
};

export async function unsubscribeWaitlist(token: string): Promise<boolean> {
  const updated = await dbQuery(
    `UPDATE waitlist_signups
     SET unsubscribed_at = now()
     WHERE unsubscribe_token = $1 AND unsubscribed_at IS NULL`,
    [token],
  );
  return (updated.rowCount ?? 0) > 0;
}
