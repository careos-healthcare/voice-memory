import { STATUS_CODES } from "node:http";
import type { IncomingMessage, Server } from "node:http";
import type { Duplex } from "node:stream";
import { parse as parseUrl } from "node:url";

import {
  listCloudRelayDevices,
  pushCloudRelayEnvelopes,
  revokeCloudRelayDevice,
  takeCloudRelayEnvelopes,
} from "@/lib/server/cloud-relay-store";
import { verifyCloudRelayToken } from "@/lib/sync/cloud-relay-auth";
import {
  CLOUD_RELAY_MAX_BATCH_BYTES,
  parseCloudRelayPushRequest,
} from "@/lib/sync/cloud-relay-contract";
import { WebSocket, WebSocketServer } from "ws";

export const CLOUD_RELAY_WS_PATH = "/api/sync-relay/ws";
const MAX_WS_BYTES = Math.ceil(CLOUD_RELAY_MAX_BATCH_BYTES * 1.5) + 8192;
const DEVICE_ID = /^[A-Za-z0-9_.:-]{1,128}$/;

function reject(socket: Duplex, statusCode: number): void {
  const statusText = STATUS_CODES[statusCode] ?? "Error";
  const body = statusCode === 401 ? "Unauthorized" : "Invalid request";
  socket.write(
    `HTTP/1.1 ${statusCode} ${statusText}\r\n` +
      "Content-Type: text/plain\r\n" +
      "Cache-Control: no-store\r\n" +
      `Content-Length: ${Buffer.byteLength(body)}\r\n` +
      "Connection: close\r\n\r\n" +
      body,
  );
  socket.destroy();
}

function send(ws: WebSocket, value: unknown): void {
  if (ws.readyState === WebSocket.OPEN) {
    ws.send(JSON.stringify(value));
  }
}

export function attachCloudRelayWebSocketUpgrade(server: Server): void {
  const wss = new WebSocketServer({
    noServer: true,
    maxPayload: MAX_WS_BYTES,
    perMessageDeflate: false,
  });
  server.on("upgrade", (request, socket, head) => {
    const parsed = parseUrl(request.url ?? "", true);
    if (parsed.pathname !== CLOUD_RELAY_WS_PATH) return;
    const token =
      typeof parsed.query.token === "string" ? parsed.query.token : "";
    const access = verifyCloudRelayToken(token);
    if (!access) {
      reject(socket, 401);
      return;
    }
    wss.handleUpgrade(request, socket, head, (ws) => {
      wss.emit("connection", ws, request);
      send(ws, { ok: true, status: "encrypted_relay_connected" });
      ws.on("message", (raw) => {
        void (async () => {
          try {
            const body = JSON.parse(
              Buffer.isBuffer(raw) ? raw.toString("utf8") : String(raw),
            ) as Record<string, unknown>;
            if (body.action === "push") {
              const parsedPush = parseCloudRelayPushRequest(body);
              if (
                parsedPush.envelopes.some(
                  (envelope) => envelope.deviceId !== access.deviceId,
                )
              ) {
                send(ws, { ok: false, code: "RELAY_DEVICE_MISMATCH" });
                return;
              }
              await pushCloudRelayEnvelopes(
                access.vaultHash,
                access.deviceId,
                parsedPush.envelopes,
              );
              send(ws, { ok: true, accepted: parsedPush.envelopes.length });
              return;
            }
            if (body.action === "pull") {
              const [envelopes, devices] = await Promise.all([
                takeCloudRelayEnvelopes(access.vaultHash, access.deviceId),
                listCloudRelayDevices(access.vaultHash),
              ]);
              send(ws, { ok: true, envelopes, devices });
              return;
            }
            if (
              body.action === "revoke" &&
              typeof body.deviceId === "string" &&
              DEVICE_ID.test(body.deviceId) &&
              body.deviceId !== access.deviceId
            ) {
              await revokeCloudRelayDevice(access.vaultHash, body.deviceId);
              send(ws, { ok: true });
              return;
            }
            send(ws, { ok: false, code: "INVALID_RELAY_REQUEST" });
          } catch {
            send(ws, { ok: false, code: "INVALID_RELAY_REQUEST" });
          }
        })();
      });
    });
  });
}
