import type { IncomingMessage } from "node:http";
import type { Server } from "node:http";
import type { Duplex } from "node:stream";
import { parse as parseUrl } from "node:url";

import { STATUS_CODES } from "node:http";

import { getGeminiApiKey, GEMINI_LIVE_MODEL_ID, isGeminiConfigured, isGeminiKillSwitchActive } from "@/lib/gemini";
import { LIVE_AUDIO_PROXY_WS_PATH } from "@/lib/live-audio/constants";
import {
  isLiveAudioDraining,
  LIVE_AUDIO_COORDINATOR_DISCONNECT,
  registerLiveAudioConnection,
} from "@/lib/live-audio/live-audio-connection-registry";
import { logLiveAudio, logLiveAudioCritical } from "@/lib/live-audio/live-audio-log";
import {
  emitSanitizedRequestLog,
  extractUserIdFromSubject,
  prepareSensitiveRequestLogFields,
} from "@/lib/server/log-sanitizer";
import { authenticateLiveAudioWebSocketUpgrade } from "@/lib/live-audio/ws-auth";
import {
  runLiveAudioProxyConnection,
  type LiveAudioClientSocket,
} from "@/lib/live-audio/ws-proxy-connection";
import { WebSocket, WebSocketServer } from "ws";

function rejectWebSocketUpgrade(
  socket: Duplex,
  statusCode: number,
  message: string,
): void {
  const statusText = STATUS_CODES[statusCode] ?? "Error";
  const body = message;
  socket.write(
    `HTTP/1.1 ${statusCode} ${statusText}\r\n` +
      "Content-Type: text/plain\r\n" +
      `Content-Length: ${Buffer.byteLength(body)}\r\n` +
      "Connection: close\r\n" +
      "\r\n" +
      body,
  );
  socket.destroy();
}

function wrapClientSocket(ws: WebSocket): LiveAudioClientSocket {
  return {
    send(data) {
      if (ws.readyState === WebSocket.OPEN) {
        ws.send(data);
      }
    },
    close(code, reason) {
      ws.close(code ?? 1000, reason);
    },
    onMessage(handler) {
      ws.on("message", (data: Buffer | ArrayBuffer | Buffer[]) => {
        if (typeof data === "string") {
          handler(data);
          return;
        }
        if (Buffer.isBuffer(data)) {
          handler(data.toString("utf8"));
          return;
        }
        if (Array.isArray(data)) {
          handler(Buffer.concat(data).toString("utf8"));
          return;
        }
        if (data instanceof ArrayBuffer) {
          handler(Buffer.from(data).toString("utf8"));
        }
      });
    },
    onClose(handler) {
      ws.on("close", handler);
    },
    onError(handler) {
      ws.on("error", handler);
    },
  };
}

/** Attaches the live-audio proxy upgrade handler to the Node HTTP server. */
export function attachLiveAudioWebSocketUpgrade(server: Server): void {
  const wss = new WebSocketServer({ noServer: true });

  server.on("upgrade", (request: IncomingMessage, socket, head) => {
    void handleUpgradeRequest(request, socket, head, wss);
  });

  logLiveAudio(`websocket upgrade attached path=${LIVE_AUDIO_PROXY_WS_PATH}`);
}

async function handleUpgradeRequest(
  request: IncomingMessage,
  socket: Duplex,
  head: Buffer,
  wss: WebSocketServer,
): Promise<void> {
  const parsed = parseUrl(request.url ?? "", true);
  if (parsed.pathname !== LIVE_AUDIO_PROXY_WS_PATH) {
    return;
  }

  if (isLiveAudioDraining()) {
    logLiveAudio(
      `upgrade rejected code=draining message=${LIVE_AUDIO_COORDINATOR_DISCONNECT}`,
    );
    rejectWebSocketUpgrade(socket, 503, LIVE_AUDIO_COORDINATOR_DISCONNECT);
    return;
  }

  const auth = await authenticateLiveAudioWebSocketUpgrade(
    request,
    parsed.query,
    {
      isGeminiConfigured,
      isGeminiKillSwitchActive,
    },
  );

  if (!auth.ok) {
    emitSanitizedRequestLog("incoming_websocket_request", prepareSensitiveRequestLogFields({
      pathname: LIVE_AUDIO_PROXY_WS_PATH,
      method: "GET",
      extra: { upgrade: "websocket", accepted: false, code: auth.code },
    }));
    logLiveAudio(
      `upgrade rejected code=${auth.code} message=${auth.message}`,
    );
    rejectWebSocketUpgrade(socket, auth.httpStatus, auth.message);
    return;
  }

  emitSanitizedRequestLog("incoming_websocket_request", prepareSensitiveRequestLogFields({
    pathname: LIVE_AUDIO_PROXY_WS_PATH,
    method: "GET",
    subject: auth.subject,
    userId: extractUserIdFromSubject(auth.subject),
    sessionId: auth.sessionId,
    extra: { upgrade: "websocket", accepted: true },
  }));

  if (isLiveAudioDraining()) {
    logLiveAudio(
      `upgrade rejected code=draining message=${LIVE_AUDIO_COORDINATOR_DISCONNECT}`,
    );
    rejectWebSocketUpgrade(socket, 503, LIVE_AUDIO_COORDINATOR_DISCONNECT);
    return;
  }

  wss.handleUpgrade(request, socket, head, (ws: WebSocket) => {
    wss.emit("connection", ws, request);
    const client = wrapClientSocket(ws);
    const unregister = registerLiveAudioConnection({
      sessionId: auth.sessionId,
      client,
      ws,
    });
    ws.once("close", unregister);

    void runLiveAudioProxyConnection({
      client,
      sessionId: auth.sessionId,
      subject: auth.subject,
      apiKey: getGeminiApiKey(),
      modelId: GEMINI_LIVE_MODEL_ID,
      systemInstruction: auth.systemInstruction,
    }).catch((error) => {
      logLiveAudioCritical("proxy session failed", error);
      ws.close(1011, "proxy_session_failed");
    });
  });
}
