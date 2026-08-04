import { createServer } from "node:http";
import path from "node:path";
import { parse as parseUrl } from "node:url";

import next from "next";

import { registerGracefulShutdown } from "@/lib/server/graceful-shutdown";
import { assertProductionUnitEconomicsIsDurable } from "@/lib/server/unit-economics-config";

function cliPort(): string | undefined {
  const index = process.argv.findIndex(
    (argument) => argument === "-p" || argument === "--port",
  );
  return index >= 0 ? process.argv[index + 1] : undefined;
}

async function main(): Promise<void> {
  assertProductionUnitEconomicsIsDurable();
  const dev = process.env.NODE_ENV !== "production";
  const hostname = process.env.HOSTNAME ?? "localhost";
  const port = Number.parseInt(process.env.PORT ?? cliPort() ?? "3000", 10);
  const appDirectory = dev
    ? process.cwd()
    : path.resolve(
        process.env.BACKEND_RELEASE_DIRECTORY ?? ".backend-release",
      );

  const app = next({ dev, dir: appDirectory, hostname, port });
  const handle = app.getRequestHandler();

  await app.prepare();

  const server = createServer((req, res) => {
    const parsedUrl = parseUrl(req.url ?? "/", true);
    handle(req, res, parsedUrl);
  });

  // The live-audio and cloud-relay WebSocket upgrades are not part of the
  // commercial V1 surface. Their route handlers live under experiments/, so
  // attaching the upgrades here would have kept /api/live-audio/ws and
  // /api/sync-relay/ws reachable whenever the app is served through this
  // entry point rather than `next start`.
  registerGracefulShutdown(server);

  server.listen(port, () => {
    console.log(`> ArchiveMe ready on http://${hostname}:${port}`);
  });
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
