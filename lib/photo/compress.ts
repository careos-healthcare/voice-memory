export interface CompressedPhoto {
  blob: Blob;
  mimeType: string;
  width: number;
  height: number;
  originalByteLength: number;
  byteLength: number;
}

const MAX_DIMENSION = 1920;
const JPEG_QUALITY = 0.82;

function loadImageFromFile(file: File): Promise<HTMLImageElement> {
  return new Promise((resolve, reject) => {
    const url = URL.createObjectURL(file);
    const image = new Image();
    image.onload = () => {
      URL.revokeObjectURL(url);
      resolve(image);
    };
    image.onerror = () => {
      URL.revokeObjectURL(url);
      reject(new Error("Could not read image"));
    };
    image.src = url;
  });
}

function scaleDimensions(
  width: number,
  height: number,
): { width: number; height: number } {
  const longest = Math.max(width, height);
  if (longest <= MAX_DIMENSION) return { width, height };

  const ratio = MAX_DIMENSION / longest;
  return {
    width: Math.round(width * ratio),
    height: Math.round(height * ratio),
  };
}

function canvasToBlob(
  canvas: HTMLCanvasElement,
  mimeType: string,
  quality: number,
): Promise<Blob> {
  return new Promise((resolve, reject) => {
    canvas.toBlob(
      (blob) => {
        if (!blob) {
          reject(new Error("Could not compress image"));
          return;
        }
        resolve(blob);
      },
      mimeType,
      quality,
    );
  });
}

/** Compress a photo before IndexedDB save — keeps memory anchors lightweight. */
export async function compressPhotoForStorage(file: File): Promise<CompressedPhoto> {
  const originalByteLength = file.size;

  if (!file.type.startsWith("image/")) {
    throw new Error("Not an image file");
  }

  const image = await loadImageFromFile(file);
  const scaled = scaleDimensions(image.naturalWidth, image.naturalHeight);

  const canvas = document.createElement("canvas");
  canvas.width = scaled.width;
  canvas.height = scaled.height;

  const ctx = canvas.getContext("2d");
  if (!ctx) throw new Error("Could not prepare image");

  ctx.drawImage(image, 0, 0, scaled.width, scaled.height);

  const outputMime =
    file.type === "image/png" && originalByteLength < 400_000
      ? "image/png"
      : "image/jpeg";
  const quality = outputMime === "image/jpeg" ? JPEG_QUALITY : undefined;

  const blob = await canvasToBlob(canvas, outputMime, quality ?? JPEG_QUALITY);

  return {
    blob,
    mimeType: outputMime,
    width: scaled.width,
    height: scaled.height,
    originalByteLength,
    byteLength: blob.size,
  };
}
