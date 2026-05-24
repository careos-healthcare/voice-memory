import { NextResponse } from "next/server";
import type { NextRequest } from "next/server";

/** Block internal debug surfaces in production unless DEBUG_ACCESS_TOKEN is supplied. */
export function middleware(request: NextRequest) {
  if (process.env.NODE_ENV !== "production") {
    return NextResponse.next();
  }

  const token = process.env.DEBUG_ACCESS_TOKEN?.trim();
  if (!token) {
    return NextResponse.redirect(new URL("/", request.url));
  }

  const cookieToken = request.cookies.get("vm_debug")?.value;
  const queryToken = request.nextUrl.searchParams.get("debug_token");
  if (cookieToken === token || queryToken === token) {
    if (queryToken === token) {
      const url = request.nextUrl.clone();
      url.searchParams.delete("debug_token");
      const response = NextResponse.redirect(url);
      response.cookies.set("vm_debug", token, {
        httpOnly: true,
        sameSite: "lax",
        secure: true,
        maxAge: 60 * 60 * 8,
        path: "/",
      });
      return response;
    }
    return NextResponse.next();
  }

  return NextResponse.redirect(new URL("/", request.url));
}

export const config = {
  matcher: "/debug/:path*",
};
