import { createDecipheriv } from "node:crypto";

export const VAULT_MAGIC = Buffer.from([0x41, 0x56, 0x4d, 0x45]); // AVME
export const VAULT_FORMAT_VERSION = 1;
export const VAULT_GCM_NONCE_BYTES = 12;
export const VAULT_GCM_MAC_BYTES = 16;

export interface VaultHeader {
  sampleRateHz: number;
  numChannels: number;
}

export interface DecryptedVaultAudio {
  header: VaultHeader;
  pcm16Le: Buffer;
  frameCount: number;
}

export function parseVaultHeader(bytes: Buffer): VaultHeader {
  if (bytes.length < 10) {
    throw new Error("Vault file is too small.");
  }
  if (!bytes.subarray(0, 4).equals(VAULT_MAGIC)) {
    throw new Error("Invalid vault magic.");
  }
  const version = bytes[4];
  if (version !== VAULT_FORMAT_VERSION) {
    throw new Error(`Unsupported vault version ${version}.`);
  }
  const sampleRateHz = bytes.readUInt32LE(5);
  const numChannels = bytes[9];
  if (sampleRateHz <= 0 || numChannels <= 0) {
    throw new Error("Invalid vault audio metadata.");
  }
  return { sampleRateHz, numChannels };
}

export function decryptVaultFile(
  vaultBytes: Buffer,
  recoverySecret: Buffer,
): DecryptedVaultAudio {
  const header = parseVaultHeader(vaultBytes);
  let offset = 10;
  const pcmChunks: Buffer[] = [];
  let frameCount = 0;

  while (offset < vaultBytes.length) {
    if (offset + 4 > vaultBytes.length) break;
    const cipherLength = vaultBytes.readUInt32LE(offset);
    offset += 4;
    const frameEnd = offset + VAULT_GCM_NONCE_BYTES + VAULT_GCM_MAC_BYTES + cipherLength;
    if (cipherLength <= 0 || frameEnd > vaultBytes.length) {
      throw new Error("Corrupt encrypted vault frame.");
    }

    const nonce = vaultBytes.subarray(offset, offset + VAULT_GCM_NONCE_BYTES);
    offset += VAULT_GCM_NONCE_BYTES;
    const mac = vaultBytes.subarray(offset, offset + VAULT_GCM_MAC_BYTES);
    offset += VAULT_GCM_MAC_BYTES;
    const ciphertext = vaultBytes.subarray(offset, offset + cipherLength);
    offset += cipherLength;

    const decipher = createDecipheriv("aes-256-gcm", recoverySecret, nonce);
    decipher.setAuthTag(mac);
    const plaintext = Buffer.concat([
      decipher.update(ciphertext),
      decipher.final(),
    ]);
    pcmChunks.push(plaintext);
    frameCount++;
  }

  if (frameCount === 0) {
    throw new Error("Vault contains no encrypted audio frames.");
  }

  return {
    header,
    pcm16Le: Buffer.concat(pcmChunks),
    frameCount,
  };
}

export function wrapPcm16LeInWav(
  pcmBytes: Buffer,
  sampleRateHz: number,
  numChannels: number,
): Buffer {
  const dataSize = pcmBytes.length;
  const byteRate = sampleRateHz * numChannels * 2;
  const blockAlign = numChannels * 2;
  const fileSize = 36 + dataSize;
  const header = Buffer.alloc(44);
  header.write("RIFF", 0);
  header.writeUInt32LE(fileSize, 4);
  header.write("WAVE", 8);
  header.write("fmt ", 12);
  header.writeUInt32LE(16, 16);
  header.writeUInt16LE(1, 20);
  header.writeUInt16LE(numChannels, 22);
  header.writeUInt32LE(sampleRateHz, 24);
  header.writeUInt32LE(byteRate, 28);
  header.writeUInt16LE(blockAlign, 32);
  header.writeUInt16LE(16, 34);
  header.write("data", 36);
  header.writeUInt32LE(dataSize, 40);
  return Buffer.concat([header, pcmBytes]);
}
