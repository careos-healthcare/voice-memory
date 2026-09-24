import { sendWaitlistConfirmation } from "@/lib/email/send-waitlist-confirmation";
import { postgresWaitlistStore } from "@/lib/waitlist/postgres-store";
import { clientIpFromRequest, signupForWaitlist } from "@/lib/waitlist/signup";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

export async function POST(request: Request) {
  let body: { email?: string };
  try {
    body = (await request.json()) as { email?: string };
  } catch {
    return Response.json(
      { ok: false, error: "Enter a valid email address." },
      { status: 400 },
    );
  }

  const result = await signupForWaitlist({
    email: body.email ?? "",
    ip: clientIpFromRequest(request),
    store: postgresWaitlistStore,
    sendConfirmation: sendWaitlistConfirmation,
  });
  return Response.json(result.body, { status: result.status });
}
