import { NextResponse } from "next/server";
import type { NextRequest } from "next/server";

import {
  debugAccessToken,
  evaluateTier1DevRoute,
  evaluateTier2InternalRouteEdge,
  INTERNAL_COOKIE,
  isDeprecatedDebugPath,
  isTier1Path,
  isTier2Path,
  readRequestAccessToken,
  tokenMatchesConfigured,
} from "@/lib/middleware/internal-gate";
import {
  isPublicProductionPath,
  isRetiredConsumerPath,
  resolvePublicRedirect,
} from "@/lib/site/web-public-production-routes";
import { isLegacyMarketingHost } from "@/lib/site/marketing-site";

function applyTokenCookieRedirect(request: NextRequest): NextResponse | null {
  const queryToken = request.nextUrl.searchParams.get("debug_token");
  const token = debugAccessToken();
  if (!queryToken || !token || queryToken !== token) return null;

  const url = request.nextUrl.clone();
  url.searchParams.delete("debug_token");
  const response = NextResponse.redirect(url);
  response.cookies.set(INTERNAL_COOKIE, token, {
    httpOnly: true,
    sameSite: "lax",
    secure: process.env.NODE_ENV === "production",
    maxAge: 60 * 60 * 8,
    path: "/",
  });
  return response;
}

function denyNotFound(): NextResponse {
  return new NextResponse(null, {
    status: 404,
    headers: { "X-Robots-Tag": "noindex, nofollow" },
  });
}

function denyGone(): NextResponse {
  return new NextResponse(null, {
    status: 410,
    headers: { "X-Robots-Tag": "noindex, nofollow" },
  });
}

/** Deny-by-default web surface — marketing/legal/support only; internal gated. */
export function middleware(request: NextRequest) {
  const host = request.headers.get("host") ?? "";
  if (isLegacyMarketingHost(host)) {
    const url = request.nextUrl.clone();
    url.protocol = "https:";
    url.host = "archiveme.app";
    return NextResponse.redirect(url, 308);
  }

  const pathname = request.nextUrl.pathname;

  if (isDeprecatedDebugPath(pathname)) {
    return denyNotFound();
  }

  const redirectTarget = resolvePublicRedirect(pathname);
  if (redirectTarget) {
    const url = request.nextUrl.clone();
    url.pathname = redirectTarget;
    return NextResponse.redirect(url, 308);
  }

  if (isTier1Path(pathname)) {
    const tier1 = evaluateTier1DevRoute(pathname);
    if (!tier1.allow) return denyNotFound();
    return NextResponse.next();
  }

  if (isTier2Path(pathname)) {
    const cookieRedirect = applyTokenCookieRedirect(request);
    if (cookieRedirect) return cookieRedirect;

    const tier2 = evaluateTier2InternalRouteEdge(request);
    if (!tier2.allow) return denyNotFound();

    if (!tokenMatchesConfigured(readRequestAccessToken(request))) {
      return denyNotFound();
    }

    const requestHeaders = new Headers(request.headers);
    requestHeaders.set("x-vm-internal-path", pathname);
    requestHeaders.set("x-vm-internal-method", request.method);

    return NextResponse.next({
      request: { headers: requestHeaders },
    });
  }

  if (isRetiredConsumerPath(pathname)) {
    return denyGone();
  }

  if (!isPublicProductionPath(pathname)) {
    return denyNotFound();
  }

  return NextResponse.next();
}

export const config = {
  matcher: [
    "/((?!_next/static|_next/image|favicon.ico|.*\\.(?:svg|png|jpg|jpeg|gif|webp|ico)$).*)",
  ],
};
