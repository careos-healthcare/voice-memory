import { unsubscribeWaitlist } from "@/lib/waitlist/postgres-store";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

export async function GET(request: Request) {
  const token = new URL(request.url).searchParams.get("token")?.trim() ?? "";
  if (!token) {
    return new Response("Missing unsubscribe token.", { status: 400 });
  }
  await unsubscribeWaitlist(token);
  return new Response("You're unsubscribed from the Thoughtprint waitlist.", {
    status: 200,
    headers: { "content-type": "text/plain; charset=utf-8" },
  });
}
