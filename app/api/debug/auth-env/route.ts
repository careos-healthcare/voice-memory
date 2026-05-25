import { NextResponse } from "next/server";

import { readAuthEmailEnvStatus } from "@/lib/server/env-check";

export const runtime = "nodejs";

/** Non-secret auth email configuration probe for production debugging. */
export async function GET() {
  const status = readAuthEmailEnvStatus();
  return NextResponse.json({
    resendConfigured: status.resendConfigured,
    emailFromConfigured: status.emailFromConfigured,
    appUrlConfigured: status.appUrlConfigured,
  });
}
