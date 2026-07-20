import { createServer } from "node:http";
import { parse as parseUrl } from "node:url";

import next from "next";

import { attachLiveAudioWebSocketUpgrade } from "@/lib/live-audio/ws-upgrade";
import { registerGracefulShutdown } from "@/lib/server/graceful-shutdown";

async function main(): Promise<void> {
  const dev = process.env.NODE_ENV !== "production";
  const hostname = process.env.HOSTNAME ?? "localhost";
  const port = Number.parseInt(process.env.PORT ?? "3000", 10);

  const app = next({ dev, hostname, port });
  const handle = app.getRequestHandler();

  await app.prepare();

  const server = createServer((req, res) => {
    const parsedUrl = parseUrl(req.url ?? "/", true);
    handle(req, res, parsedUrl);
  });

  attachLiveAudioWebSocketUpgrade(server);
  registerGracefulShutdown(server);

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
