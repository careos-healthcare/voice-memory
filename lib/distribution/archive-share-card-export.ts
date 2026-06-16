import type { ArchiveShareCardModel } from "@/types/distribution";

const WIDTH = 1080;
const HEIGHT = 1080;
const BACKGROUND = "#09090b";
const LINE_COLOR = "#f4f4f5";
const SUBLINE_COLOR = "#71717a";
const ACCENT = "#a78bfa";

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

export function renderArchiveShareCardCanvas(
  card: ArchiveShareCardModel,
): HTMLCanvasElement {
  const canvas = document.createElement("canvas");
  canvas.width = WIDTH;
  canvas.height = HEIGHT;
  const ctx = canvas.getContext("2d");
  if (!ctx) return canvas;

  ctx.fillStyle = BACKGROUND;
  ctx.fillRect(0, 0, WIDTH, HEIGHT);

  ctx.strokeStyle = `${ACCENT}33`;
  ctx.lineWidth = 2;
  ctx.strokeRect(48, 48, WIDTH - 96, HEIGHT - 96);

  ctx.font = "600 13px system-ui, -apple-system, sans-serif";
  ctx.fillStyle = ACCENT;
  ctx.textAlign = "center";
  ctx.fillText("ArchiveMe", WIDTH / 2, 120);

  ctx.font = "400 42px Georgia, 'Times New Roman', serif";
  ctx.fillStyle = LINE_COLOR;
  const lines = wrapText(ctx, card.line, WIDTH - 160);
  const lineHeight = 56;
  let y = (HEIGHT - lines.length * lineHeight) / 2;
  for (const line of lines) {
    ctx.fillText(line, WIDTH / 2, y);
    y += lineHeight;
  }

  if (card.subline) {
    ctx.font = "400 14px system-ui, -apple-system, sans-serif";
    ctx.fillStyle = SUBLINE_COLOR;
    ctx.fillText(card.subline, WIDTH / 2, HEIGHT - 96);
  }

  return canvas;
}

export async function exportArchiveShareCardPng(
  card: ArchiveShareCardModel,
): Promise<Blob> {
  const canvas = renderArchiveShareCardCanvas(card);
  return new Promise((resolve, reject) => {
    canvas.toBlob(
      (blob) => {
        if (blob) resolve(blob);
        else reject(new Error("Failed to export share card"));
      },
      "image/png",
      1,
    );
  });
}
