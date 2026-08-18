declare module "ws" {
  import type { IncomingMessage } from "node:http";
  import type { Duplex } from "node:stream";
  import { EventEmitter } from "node:events";

  export class WebSocket extends EventEmitter {
    static readonly OPEN: number;
    readonly readyState: number;
    send(data: string | Buffer): void;
    close(code?: number, reason?: string): void;
    terminate(): void;
    on(event: "message", listener: (data: Buffer | ArrayBuffer | Buffer[]) => void): this;
    on(event: "close", listener: () => void): this;
    on(event: "error", listener: (error: Error) => void): this;
    once(event: "close", listener: () => void): this;
  }

  export class WebSocketServer extends EventEmitter {
    constructor(options?: { noServer?: boolean });
    handleUpgrade(
      request: IncomingMessage,
      socket: Duplex,
      head: Buffer,
      callback: (ws: WebSocket) => void,
    ): void;
  }

  export { WebSocket as default };
}
