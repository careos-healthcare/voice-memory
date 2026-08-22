const CRC_TABLE = (() => {
  const table = new Uint32Array(256);
  for (let i = 0; i < 256; i++) {
    let c = i;
    for (let k = 0; k < 8; k++) {
      c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
    }
    table[i] = c >>> 0;
  }
  return table;
})();

function crc32(bytes: Uint8Array): number {
  let crc = 0xffffffff;
  for (const byte of bytes) {
    crc = CRC_TABLE[(crc ^ byte) & 0xff]! ^ (crc >>> 8);
  }
  return (crc ^ 0xffffffff) >>> 0;
}

function u32(value: number): Uint8Array {
  return new Uint8Array([
    value & 0xff,
    (value >>> 8) & 0xff,
    (value >>> 16) & 0xff,
    (value >>> 24) & 0xff,
  ]);
}

function encodeAscii(text: string): Uint8Array {
  return new TextEncoder().encode(text);
}

function buildTextChunk(keyword: string, text: string): Uint8Array {
  const keywordBytes = encodeAscii(keyword);
  const textBytes = encodeAscii(text);
  const data = new Uint8Array(keywordBytes.length + 1 + textBytes.length);
  data.set(keywordBytes, 0);
  data[keywordBytes.length] = 0;
  data.set(textBytes, keywordBytes.length + 1);

  const type = encodeAscii("tEXt");
  const crcInput = new Uint8Array(type.length + data.length);
  crcInput.set(type, 0);
  crcInput.set(data, type.length);

  const chunk = new Uint8Array(4 + type.length + data.length + 4);
  chunk.set(u32(data.length), 0);
  chunk.set(type, 4);
  chunk.set(data, 8);
  chunk.set(u32(crc32(crcInput)), 8 + data.length);
  return chunk;
}

function findIendOffset(png: Uint8Array): number {
  for (let i = png.length - 12; i >= 8; i--) {
    if (
      png[i + 4] === 0x49 &&
      png[i + 5] === 0x45 &&
      png[i + 6] === 0x4e &&
      png[i + 7] === 0x44
    ) {
      return i;
    }
  }
  throw new Error("PNG IEND chunk not found");
}

/** Inserts PNG tEXt metadata chunks before IEND (referral attribution). */
export function embedPngTextMetadata(
  pngBytes: Uint8Array,
  entries: Record<string, string>,
): Uint8Array {
  const iendOffset = findIendOffset(pngBytes);
  const chunks = Object.entries(entries).map(([keyword, value]) =>
    buildTextChunk(keyword, value),
  );
  const extraLength = chunks.reduce((sum, chunk) => sum + chunk.length, 0);
  const output = new Uint8Array(pngBytes.length + extraLength);
  output.set(pngBytes.subarray(0, iendOffset), 0);
  let cursor = iendOffset;
  for (const chunk of chunks) {
    output.set(chunk, cursor);
    cursor += chunk.length;
  }
  output.set(pngBytes.subarray(iendOffset), cursor);
  return output;
}
