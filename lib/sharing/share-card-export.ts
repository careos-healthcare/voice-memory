import type { QuietShareCard } from "@/types/sharing";

const WIDTH = 800;
const HEIGHT = 480;
const BACKGROUND = "#09090b";
const LINE_COLOR = "#d4d4d8";
const LABEL_COLOR = "#71717a";
const FOOTER_COLOR = "#52525b";

function wrapText(
  ctx: CanvasRenderingContext2D,
  text: string,
  maxWidth: number,
): string[] {
  const words = text.split(/\s+/);
  const lines: string[] = [];
  let current = "";

  for (const word of words) {
    const next = current ? `${current} ${word}` : word;
    if (ctx.measureText(next).width <= maxWidth) {
      current = next;
    } else {
      if (current) lines.push(current);
      current = word;
    }
  }
  if (current) lines.push(current);
  return lines.length > 0 ? lines : [text];
}

export function renderQuietShareCardCanvas(card: QuietShareCard): HTMLCanvasElement {
  const canvas = document.createElement("canvas");
  canvas.width = WIDTH;
  canvas.height = HEIGHT;
  const ctx = canvas.getContext("2d");
  if (!ctx) return canvas;

  ctx.fillStyle = BACKGROUND;
  ctx.fillRect(0, 0, WIDTH, HEIGHT);

  let y = HEIGHT * 0.32;

  if (card.beforeLabel || card.nowLabel) {
    ctx.font = "500 11px system-ui, -apple-system, sans-serif";
    ctx.fillStyle = LABEL_COLOR;
    ctx.textAlign = "center";
    const label = [card.beforeLabel, card.nowLabel].filter(Boolean).join(" · ");
    ctx.fillText(label.toUpperCase(), WIDTH / 2, y);
    y += 28;
  }

  ctx.font = "400 28px Georgia, 'Times New Roman', serif";
  ctx.fillStyle = LINE_COLOR;
  ctx.textAlign = "center";

  const lines = wrapText(ctx, card.line, WIDTH - 120);
  const lineHeight = 38;
  const blockHeight = lines.length * lineHeight;
  y = (HEIGHT - blockHeight) / 2 + (card.beforeLabel || card.nowLabel ? 20 : 0);

  for (const line of lines) {
    ctx.fillText(line, WIDTH / 2, y);
    y += lineHeight;
  }

  ctx.font = "400 10px system-ui, -apple-system, sans-serif";
  ctx.fillStyle = FOOTER_COLOR;
  ctx.textAlign = "center";
  ctx.fillText("ArchiveMe", WIDTH / 2, HEIGHT - 36);

  return canvas;
}

export async function exportQuietShareCardPng(card: QuietShareCard): Promise<Blob> {
  const canvas = renderQuietShareCardCanvas(card);
  return new Promise((resolve, reject) => {
    canvas.toBlob(
      (blob) => {
        if (blob) resolve(blob);
        else reject(new Error("PNG export failed"));
      },
      "image/png",
      1,
    );
  });
}

export function downloadQuietShareCardPng(card: QuietShareCard): Promise<void> {
  return exportQuietShareCardPng(card).then((blob) => {
    const url = URL.createObjectURL(blob);
    const anchor = document.createElement("a");
    anchor.href = url;
    anchor.download = `archiveme-${card.id.slice(0, 12)}.png`;
    anchor.click();
    URL.revokeObjectURL(url);
  });
}

export function buildQuietShareCardPlainText(card: QuietShareCard): string {
  const parts = [card.line];
  if (card.beforeLabel && card.nowLabel) {
    parts.unshift(`${card.beforeLabel} · ${card.nowLabel}`);
  }
  parts.push("", "ArchiveMe");
  return parts.join("\n");
}
