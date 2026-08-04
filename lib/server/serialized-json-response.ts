export function serializeJsonBody(value: unknown): {
  body: string;
  bytes: number;
} {
  const body = JSON.stringify(value);
  return { body, bytes: Buffer.byteLength(body, "utf8") };
}

export function serializedJsonResponse(
  serialized: { body: string },
  init: ResponseInit = {},
): Response {
  const headers = new Headers(init.headers);
  if (!headers.has("content-type")) {
    headers.set("content-type", "application/json; charset=utf-8");
  }
  return new Response(serialized.body, { ...init, headers });
}
