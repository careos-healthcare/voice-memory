import type { JournalEntry } from "@/types/journal";
import type {
  AtmosphereSignals,
  AtmosphereStyle,
  EntryAtmosphereMeta,
} from "@/types/atmosphere";

const STYLE_KEY = "voicememory_atmosphere_style";

const WEATHER_RE =
  /\b(rain|raining|rainy|storm|stormy|cloud|cloudy|overcast|fog|foggy|mist|misty|snow|snowy|wind|windy|drizzle|grey|gray|sunny|sunlight|humid|cold|chilly|warm outside)\b/i;

export const ATMOSPHERE_STYLE_OPTIONS: Array<{
  id: AtmosphereStyle;
  label: string;
  detail: string;
}> = [
  { id: "soft-light", label: "Soft light", detail: "Diffused pale glow" },
  { id: "rainy-window", label: "Rainy window", detail: "Cool streaks, abstract" },
  { id: "quiet-room", label: "Quiet room", detail: "Warm neutral haze" },
  { id: "dusk-field", label: "Dusk field", detail: "Muted violet-orange" },
  { id: "foggy-street", label: "Foggy street", detail: "Soft grey-violet haze" },
  { id: "morning-glow", label: "Morning glow", detail: "Pale gold and cream" },
  {
    id: "abstract-color-field",
    label: "Abstract color field",
    detail: "Pure gradients only",
  },
];

const STYLE_PROMPT: Record<AtmosphereStyle, string> = {
  "soft-light": "diffused pale light with gentle neutral gradients",
  "rainy-window": "abstract cool grey-blue vertical streaks like rain on glass, no window frame",
  "quiet-room": "subtle warm neutral interior glow, abstract only, no furniture",
  "dusk-field": "muted violet and orange horizon gradient, no landscape detail",
  "foggy-street": "soft grey-violet atmospheric haze, no street or buildings",
  "morning-glow": "pale gold and cream hazy light",
  "abstract-color-field": "pure abstract color gradients, no identifiable forms",
};

const FALLBACK_PALETTES: Record<
  AtmosphereStyle,
  Array<[string, string, string]>
> = {
  "soft-light": [
    ["#e8e4dc", "#d4cfc4", "#c9c3b8"],
    ["#efeae3", "#ddd6cc", "#cfc7bb"],
  ],
  "rainy-window": [
    ["#8a939c", "#6e7882", "#556069"],
    ["#9aa3ad", "#788590", "#5c6770"],
  ],
  "quiet-room": [
    ["#d9cfc0", "#c4b5a3", "#a89888"],
    ["#e0d5c8", "#cbbfaf", "#b5a595"],
  ],
  "dusk-field": [
    ["#5c4a62", "#8a5f72", "#c47a62"],
    ["#4a3d58", "#7d5570", "#b87360"],
  ],
  "foggy-street": [
    ["#8b9099", "#737983", "#5c6168"],
    ["#9da2ab", "#808690", "#656b74"],
  ],
  "morning-glow": [
    ["#f2e8d4", "#e8d4b0", "#d9bc8c"],
    ["#faf3e6", "#eddcc0", "#dfc59a"],
  ],
  "abstract-color-field": [
    ["#c8b8d8", "#a8b8d0", "#d0c8b0"],
    ["#b0a8c8", "#98a8c0", "#c0b8a0"],
  ],
};

export function getStoredAtmosphereStyle(): AtmosphereStyle {
  if (typeof window === "undefined") return "abstract-color-field";
  const stored = localStorage.getItem(STYLE_KEY);
  if (stored && ATMOSPHERE_STYLE_OPTIONS.some((row) => row.id === stored)) {
    return stored as AtmosphereStyle;
  }
  return "abstract-color-field";
}

export function setStoredAtmosphereStyle(style: AtmosphereStyle): void {
  if (typeof window === "undefined") return;
  localStorage.setItem(STYLE_KEY, style);
}

export function timeOfDayFromIso(iso: string): AtmosphereSignals["timeOfDay"] {
  const hour = new Date(iso).getHours();
  if (hour >= 5 && hour < 11) return "morning";
  if (hour >= 17 && hour < 21) return "evening";
  if (hour >= 21 || hour < 5) return "night";
  return "day";
}

export function extractWeatherHint(text: string): string | null {
  const match = text.match(WEATHER_RE);
  if (!match) return null;
  return match[0].toLowerCase();
}

export function extractToneHint(entry: JournalEntry): string | null {
  const mood = entry.reflection.mood?.trim();
  const intensity = entry.reflection.emotionalIntensity;
  if (!mood) return null;
  if (intensity >= 7) return `quiet ${mood.toLowerCase()} weight`;
  if (intensity <= 4) return `soft ${mood.toLowerCase()} calm`;
  return `steady ${mood.toLowerCase()} tone`;
}

export function buildAtmosphereSignals(
  entry: JournalEntry,
  colorHints: string[] = [],
): AtmosphereSignals {
  const text = [
    entry.transcript,
    entry.reflection.concreteObservation,
    entry.reflection.exactLanguagePattern,
  ]
    .filter(Boolean)
    .join(" ");

  return {
    timeOfDay: timeOfDayFromIso(entry.createdAt),
    weatherHint: extractWeatherHint(text),
    toneHint: extractToneHint(entry),
    colorHints,
  };
}

function timePhrase(timeOfDay: AtmosphereSignals["timeOfDay"]): string {
  switch (timeOfDay) {
    case "morning":
      return "early morning light";
    case "evening":
      return "late evening dimness";
    case "night":
      return "night quiet";
    default:
      return "daytime softness";
  }
}

/** Non-literal atmosphere prompt — no people, faces, or narrative scenes. */
export function buildAtmospherePrompt(
  style: AtmosphereStyle,
  signals: AtmosphereSignals,
): string {
  const parts = [
    "Abstract minimal atmosphere only.",
    STYLE_PROMPT[style],
    "Non-representational color fields.",
    "No people, no faces, no figures, no text, no objects, no narrative scene.",
    "No cinematic drama, no fantasy, no therapy symbolism.",
    timePhrase(signals.timeOfDay),
  ];

  if (signals.weatherHint) {
    parts.push(`Weather-like mood: ${signals.weatherHint}, abstract only.`);
  }
  if (signals.toneHint) {
    parts.push(`Emotional softness: ${signals.toneHint}, non-literal.`);
  }
  if (signals.colorHints.length > 0) {
    parts.push(`Palette hints: ${signals.colorHints.join(", ")}.`);
  }

  return parts.join(" ");
}

export async function extractPhotoColorHints(blob: Blob): Promise<string[]> {
  if (typeof document === "undefined") return [];

  return new Promise((resolve) => {
    const url = URL.createObjectURL(blob);
    const image = new Image();
    image.onload = () => {
      URL.revokeObjectURL(url);
      try {
        const canvas = document.createElement("canvas");
        const size = 24;
        canvas.width = size;
        canvas.height = size;
        const ctx = canvas.getContext("2d");
        if (!ctx) {
          resolve([]);
          return;
        }
        ctx.drawImage(image, 0, 0, size, size);
        const data = ctx.getImageData(0, 0, size, size).data;
        const buckets = new Map<string, number>();
        for (let i = 0; i < data.length; i += 16) {
          const r = Math.round(data[i] / 32) * 32;
          const g = Math.round(data[i + 1] / 32) * 32;
          const b = Math.round(data[i + 2] / 32) * 32;
          const key = `#${[r, g, b].map((v) => v.toString(16).padStart(2, "0")).join("")}`;
          buckets.set(key, (buckets.get(key) ?? 0) + 1);
        }
        const top = [...buckets.entries()]
          .sort((a, b) => b[1] - a[1])
          .slice(0, 3)
          .map(([color]) => color);
        resolve(top);
      } catch {
        resolve([]);
      }
    };
    image.onerror = () => {
      URL.revokeObjectURL(url);
      resolve([]);
    };
    image.src = url;
  });
}

function pickPalette(style: AtmosphereStyle, signals: AtmosphereSignals): string[] {
  const options = FALLBACK_PALETTES[style];
  const index =
    (signals.colorHints.length + signals.timeOfDay.length + style.length) %
    options.length;
  return options[index];
}

function drawRadialGradient(
  ctx: CanvasRenderingContext2D,
  width: number,
  height: number,
  colors: string[],
): void {
  const gradient = ctx.createRadialGradient(
    width * 0.35,
    height * 0.3,
    width * 0.05,
    width * 0.5,
    height * 0.5,
    width * 0.75,
  );
  gradient.addColorStop(0, colors[0]);
  gradient.addColorStop(0.55, colors[1] ?? colors[0]);
  gradient.addColorStop(1, colors[2] ?? colors[1] ?? colors[0]);
  ctx.fillStyle = gradient;
  ctx.fillRect(0, 0, width, height);
}

function drawStyleOverlay(
  ctx: CanvasRenderingContext2D,
  width: number,
  height: number,
  style: AtmosphereStyle,
): void {
  if (style === "rainy-window") {
    ctx.globalAlpha = 0.12;
    ctx.strokeStyle = "#ffffff";
    for (let x = 0; x < width; x += 14) {
      ctx.beginPath();
      ctx.moveTo(x, 0);
      ctx.lineTo(x - 8, height);
      ctx.stroke();
    }
    ctx.globalAlpha = 1;
    return;
  }

  if (style === "foggy-street" || style === "morning-glow") {
    const fog = ctx.createLinearGradient(0, height * 0.4, 0, height);
    fog.addColorStop(0, "rgba(255,255,255,0)");
    fog.addColorStop(1, "rgba(255,255,255,0.22)");
    ctx.fillStyle = fog;
    ctx.fillRect(0, 0, width, height);
  }
}

/** Local abstract fallback when image API is unavailable. */
export async function renderFallbackAtmosphereBlob(
  style: AtmosphereStyle,
  signals: AtmosphereSignals,
  width = 960,
  height = 600,
): Promise<Blob> {
  const canvas = document.createElement("canvas");
  canvas.width = width;
  canvas.height = height;
  const ctx = canvas.getContext("2d");
  if (!ctx) throw new Error("Could not render atmosphere");

  const colors =
    signals.colorHints.length >= 2
      ? [...signals.colorHints, signals.colorHints[0]]
      : pickPalette(style, signals);

  drawRadialGradient(ctx, width, height, colors);
  drawStyleOverlay(ctx, width, height, style);

  return new Promise((resolve, reject) => {
    canvas.toBlob(
      (blob) => {
        if (!blob) {
          reject(new Error("Could not create atmosphere image"));
          return;
        }
        resolve(blob);
      },
      "image/png",
      0.92,
    );
  });
}

export function buildAtmosphereMeta(
  entryId: string,
  style: AtmosphereStyle,
  prompt: string,
  source: EntryAtmosphereMeta["source"],
  width: number,
  height: number,
  byteLength: number,
): EntryAtmosphereMeta {
  return {
    atmosphereId: entryId,
    style,
    prompt,
    source,
    mimeType: "image/png",
    width,
    height,
    byteLength,
    createdAt: new Date().toISOString(),
  };
}

export async function requestAtmosphereImage(
  prompt: string,
  style: AtmosphereStyle,
  signals: AtmosphereSignals,
): Promise<{ blob: Blob; source: EntryAtmosphereMeta["source"]; width: number; height: number }> {
  try {
    const response = await fetch("/api/atmosphere", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ prompt, style }),
    });

    if (response.ok) {
      const payload = (await response.json()) as {
        source?: string;
        dataBase64?: string;
        width?: number;
        height?: number;
      };

      if (payload.source === "api" && payload.dataBase64) {
        const binary = atob(payload.dataBase64);
        const bytes = new Uint8Array(binary.length);
        for (let i = 0; i < binary.length; i += 1) bytes[i] = binary.charCodeAt(i);
        const blob = new Blob([bytes], { type: "image/png" });
        return {
          blob,
          source: "api",
          width: payload.width ?? 1024,
          height: payload.height ?? 1024,
        };
      }
    }
  } catch {
    // Fall through to local fallback.
  }

  const blob = await renderFallbackAtmosphereBlob(style, signals);
  return { blob, source: "fallback", width: 960, height: 600 };
}
