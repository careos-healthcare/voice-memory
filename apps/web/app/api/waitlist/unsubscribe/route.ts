import { unsubscribeWaitlist, waitlistTokenMatchesEmail } from "@/lib/waitlist/postgres-store";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

function escapeHtml(value: string): string {
  return value
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;");
}

function confirmationPage(token: string, email: string): string {
  return `<!DOCTYPE html>
<html lang="en">
<head><meta charset="utf-8"><title>Unsubscribe</title></head>
<body>
  <h1>Unsubscribe from the Thoughtprint waitlist</h1>
  <p>This removes your email from the launch announcement.</p>
  <form method="post" action="/api/waitlist/unsubscribe">
    <input type="hidden" name="token" value="${escapeHtml(token)}">
    <input type="hidden" name="email" value="${escapeHtml(email)}">
    <button type="submit">Confirm Unsubscribe</button>
  </form>
</body>
</html>`;
}

export async function GET(request: Request) {
  const url = new URL(request.url);
  const token = url.searchParams.get("token")?.trim() ?? "";
  const email = url.searchParams.get("email")?.trim() ?? "";
  if (!token) {
    return new Response("Missing unsubscribe token.", { status: 400 });
  }
  if (email && !(await waitlistTokenMatchesEmail(token, email))) {
    return new Response("This unsubscribe link does not match a waitlist email.", {
      status: 400,
    });
  }
  return new Response(confirmationPage(token, email), {
    status: 200,
    headers: { "content-type": "text/html; charset=utf-8" },
  });
}

export async function POST(request: Request) {
  const url = new URL(request.url);
  let token = url.searchParams.get("token")?.trim() ?? "";
  let email = url.searchParams.get("email")?.trim() ?? "";
  const contentType = request.headers.get("content-type") ?? "";
  if (contentType.includes("application/json")) {
    const body = (await request.json()) as { token?: string; email?: string };
    token = body.token?.trim() || token;
    email = body.email?.trim() || email;
  } else if (
    contentType.includes("application/x-www-form-urlencoded") ||
    contentType.includes("multipart/form-data")
  ) {
    const form = await request.formData();
    token = String(form.get("token") ?? token).trim();
    email = String(form.get("email") ?? email).trim();
  }
  if (!token) {
    return new Response("Missing unsubscribe token.", { status: 400 });
  }
  if (email && !(await waitlistTokenMatchesEmail(token, email))) {
    return new Response("This unsubscribe link does not match a waitlist email.", {
      status: 400,
    });
  }
  const removed = await unsubscribeWaitlist({ token, email });
  if (!removed) {
    return new Response("This unsubscribe link does not match a waitlist email.", {
      status: 400,
    });
  }
  return new Response("You're unsubscribed from the Thoughtprint waitlist.", {
    status: 200,
    headers: { "content-type": "text/plain; charset=utf-8" },
  });
}
