import { createServer } from "node:http";
import { parse as parseUrl } from "node:url";

import next from "next";

import {
  closeRedisClient,
  enforceGlobalRateLimitForNodeRequest,
} from "@/lib/rate-limit/enforce";
import { logIncomingHttpRequest } from "@/lib/utils/logger";
import { attachLiveAudioWebSocketUpgrade } from "@/lib/live-audio/ws-upgrade";
import { registerGracefulShutdown } from "@/lib/server/graceful-shutdown";

async function main(): Promise<void> {
  const dev = process.env.NODE_ENV !== "production";
  const hostname = process.env.HOSTNAME ?? "localhost";
  const port = Number.parseInt(process.env.PORT ?? "3000", 10);

  const app = next({ dev, hostname, port });
  const handle = app.getRequestHandler();

  await app.prepare();

  const server = createServer(async (req, res) => {
    const parsedUrl = parseUrl(req.url ?? "/", true);
    const pathname = parsedUrl.pathname ?? "/";

    try {
      const rateLimit = await enforceGlobalRateLimitForNodeRequest(req, pathname);
      if (pathname.startsWith("/api/insights") || pathname.startsWith("/api/live-audio")) {
        logIncomingHttpRequest({
          method: req.method,
          pathname,
          subject: rateLimit.subject,
        });
      }
      if (!rateLimit.allowed) {
        res.statusCode = 429;
        res.setHeader("Content-Type", "application/json");
        res.setHeader(
          "Retry-After",
          String(Math.max(1, Math.ceil(rateLimit.retryAfterMs / 1000))),
        );
        res.setHeader("X-RateLimit-Limit", "120");
        res.setHeader("X-RateLimit-Remaining", String(rateLimit.remaining));
        res.end(
          JSON.stringify({
            error: "Too many requests. Wait a minute and try again.",
            code: "RATE_LIMIT_GLOBAL",
          }),
        );
        return;
      }
    } catch (error) {
      console.error("global_rate_limit_failed", error);
      res.statusCode = 503;
      res.setHeader("Content-Type", "application/json");
      res.end(
        JSON.stringify({
          error: "Rate limiting is temporarily unavailable.",
          code: "RATE_LIMIT_UNAVAILABLE",
        }),
      );
      return;
    }

    handle(req, res, parsedUrl);
  });

  attachLiveAudioWebSocketUpgrade(server);
  registerGracefulShutdown(server);
  process.once("beforeExit", () => {
    void closeRedisClient();
  });

  server.listen(port, () => {
    console.log(`> ArchiveMe ready on http://${hostname}:${port}`);
    console.log(
      `> Live audio proxy: ws://${hostname}:${port}/api/live-audio/ws`,
    );
  });
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
