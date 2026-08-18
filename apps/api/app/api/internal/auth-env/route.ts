import { NextResponse } from "next/server";

import { readAuthEmailEnvStatus } from "@/lib/server/env-check";
import {
  debugAccessToken,
  hasFounderDebugCookie,
  isFounderEmail,
} from "@/lib/server/founder-access";
import { getServerSession } from "@/lib/server/session";
import { isInternalSurfaceEnabled } from "@/lib/server/internal-access";

export const runtime = "nodejs";

/** Non-secret auth email env probe — founder/token only. */
export async function GET() {
  if (!isInternalSurfaceEnabled()) {
    return new NextResponse(null, { status: 404 });
  }

  const token = debugAccessToken();
  const cookieOk = await hasFounderDebugCookie();
  const session = await getServerSession();
  const founderOk = session?.email ? isFounderEmail(session.email) : false;

  if (!token || (!cookieOk && !founderOk)) {
    return new NextResponse(null, { status: 404 });
  }

  const status = readAuthEmailEnvStatus();
  return NextResponse.json({
    resendConfigured: status.resendConfigured,
    emailFromConfigured: status.emailFromConfigured,
    emailFromUsesResendSandbox: status.emailFromUsesResendSandbox,
    emailFromDomain: status.emailFromDomain,
    appUrlConfigured: status.appUrlConfigured,
    productionEmailReady:
      status.resendConfigured &&
      status.emailFromConfigured &&
      status.emailFromFormatValid &&
      !status.emailFromUsesResendSandbox,
  });
}
