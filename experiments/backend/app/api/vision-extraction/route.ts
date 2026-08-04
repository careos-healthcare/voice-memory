import { Buffer } from "node:buffer";

import { getOpenAIClient } from "@/lib/openai";
import {
  ephemeralAiJson,
  logEphemeralAiFailure,
} from "@/lib/privacy/ephemeral-ai-response";
import {
  guardOpenAiRoute,
  type ApiGuardContext,
} from "@/lib/server/api-guard";
import { isAllowedVoiceSessionOrigin } from "@/lib/server/allowed-api-origin";
import { safeOpenAiRouteError } from "@/lib/server/openai-budget-guard";
import {
  meterBestEffort,
  meterConfiguredOpenAiChatUsage,
  vendorRequestId,
} from "@/lib/server/unit-economics-meter";
import {
  parseVisionExtraction,
  VisionExtractionSchema,
} from "@/lib/vision-extraction/vision-extraction-contract";
import { releaseUsageReservation } from "@/lib/server/usage-reservation-store";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

export const MAX_VISION_IMAGE_BYTES = 4 * 1024 * 1024;
const MODEL = "gpt-4o-mini";
const ALLOWED_IMAGE_TYPES = new Set(["image/jpeg", "image/png", "image/webp"]);
const SYSTEM_PROMPT = [
  "Extract only directly observable visual information from the supplied image.",
  "Describe the scene briefly, transcribe visible text exactly when legible, list observable entities, and add only clearly visible relationships between listed entity labels.",
  "Do not identify or guess the identity of any person, including public figures.",
  "Do not infer protected traits, emotions, intent, health conditions, diagnoses, or other sensitive attributes.",
  "Use lower confidence when visual evidence is ambiguous and omit speculative details.",
].join(" ");

export async function GET() {
  return ephemeralAiJson(
    {
      route: "/api/vision-extraction",
      methods: ["POST"],
      multipartField: "image",
      acceptedMediaTypes: [...ALLOWED_IMAGE_TYPES],
      maxImageBytes: MAX_VISION_IMAGE_BYTES,
      captureTokenHeader: "x-vm-capture-token",
      code: "METHOD_NOT_ALLOWED",
      error: "Use POST with a JPEG, PNG, or WebP image.",
    },
    { status: 405 },
  );
}

export async function POST(request: Request) {
  if (!isAllowedVoiceSessionOrigin(request)) {
    return ephemeralAiJson(
      { error: "Request origin is not permitted.", code: "ORIGIN_NOT_ALLOWED" },
      { status: 403 },
    );
  }

  let guardContext: ApiGuardContext | undefined;
  try {
    const ingressPromise = request.clone().arrayBuffer();
    let formData: FormData;
    try {
      formData = await request.formData();
    } catch {
      return ephemeralAiJson(
        {
          error: "Request must be multipart form data.",
          code: "INVALID_MULTIPART",
        },
        { status: 400 },
      );
    }

    const image = formData.get("image");
    if (!(image instanceof File) || image.size === 0) {
      return ephemeralAiJson(
        { error: "Image file is required.", code: "IMAGE_REQUIRED" },
        { status: 400 },
      );
    }
    if (image.size > MAX_VISION_IMAGE_BYTES) {
      return ephemeralAiJson(
        {
          error: "Image must be 4MB or smaller.",
          code: "PAYLOAD_TOO_LARGE",
        },
        { status: 413 },
      );
    }
    if (!ALLOWED_IMAGE_TYPES.has(image.type)) {
      return ephemeralAiJson(
        {
          error: "Image must be JPEG, PNG, or WebP.",
          code: "UNSUPPORTED_IMAGE_TYPE",
        },
        { status: 415 },
      );
    }

    const imageBytes = new Uint8Array(await image.arrayBuffer());
    if (!matchesImageSignature(image.type, imageBytes)) {
      return ephemeralAiJson(
        {
          error: "Image contents do not match its media type.",
          code: "INVALID_IMAGE",
        },
        { status: 400 },
      );
    }

    const guard = await guardOpenAiRoute(request, "analyze");
    if (!guard.ok) return ephemeralGuardResponse(guard.response);
    guardContext = guard.ctx;

    const ingressBytes = (await ingressPromise).byteLength;
    await meterBestEffort({
      operation: "vision-extraction.ingress",
      subject: guardContext,
      idempotencyKey:
        request.headers.get("x-vm-idempotency-key")?.trim() || undefined,
      metric: "ingress_bytes",
      resource: "network.ingress",
      quantity: ingressBytes,
      measurementBasis: "exact",
    });

    const dataUrl = `data:${image.type};base64,${Buffer.from(imageBytes).toString("base64")}`;
    const completion = await getOpenAIClient().chat.completions.create({
      model: MODEL,
      store: false,
      temperature: 0,
      messages: [
        { role: "system", content: SYSTEM_PROMPT },
        {
          role: "user",
          content: [
            {
              type: "text",
              text: "Return the structured observational extraction for this image.",
            },
            {
              type: "image_url",
              image_url: { url: dataUrl, detail: "auto" },
            },
          ],
        },
      ],
      response_format: {
        type: "json_schema",
        json_schema: {
          name: "vision_extraction",
          strict: true,
          schema: VisionExtractionSchema,
        },
      },
    });

    await meterConfiguredOpenAiChatUsage({
      operation: "vision-extraction.chat",
      subject: guardContext,
      idempotencyKey: vendorRequestId(completion),
      model: MODEL,
      usage: completion.usage,
    });

    const content = completion.choices[0]?.message.content;
    if (!content) throw new Error("VISION_EXTRACTION_EMPTY");
    return ephemeralAiJson(parseVisionExtraction(JSON.parse(content)));
  } catch (error) {
    const reservationId = guardContext?.monetization?.reservation?.reservationId;
    if (reservationId) await releaseUsageReservation(reservationId);
    logEphemeralAiFailure("/api/vision-extraction", error);
    const safe = safeOpenAiRouteError("analyze", error);
    return ephemeralAiJson(
      { error: safe.message, code: safe.code },
      { status: 500 },
    );
  }
}

async function ephemeralGuardResponse(response: Response) {
  const retryAfter = response.headers.get("retry-after");
  const body = await response.json().catch(() => ({
    error: "Vision extraction is temporarily unavailable.",
    code: "ANALYZE_UNAVAILABLE",
  }));
  return ephemeralAiJson(body, {
    status: response.status,
    headers: retryAfter ? { "Retry-After": retryAfter } : undefined,
  });
}

function matchesImageSignature(
  mediaType: string,
  bytes: Uint8Array,
): boolean {
  if (mediaType === "image/jpeg") {
    return bytes.length >= 3 && bytes[0] === 0xff && bytes[1] === 0xd8 && bytes[2] === 0xff;
  }
  if (mediaType === "image/png") {
    const signature = [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a];
    return signature.every((byte, index) => bytes[index] === byte);
  }
  return (
    bytes.length >= 12 &&
    String.fromCharCode(...bytes.subarray(0, 4)) === "RIFF" &&
    String.fromCharCode(...bytes.subarray(8, 12)) === "WEBP"
  );
}
