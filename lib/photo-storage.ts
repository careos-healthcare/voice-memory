import { hashPhotoBlob } from "@/lib/photo/integrity";

const DB_NAME = "voicememory_photos";
const DB_VERSION = 1;
const STORE = "attachments";

export interface StoredPhotoRecord {
  entryId: string;
  blob: Blob;
  mimeType: string;
  savedAt: string;
  byteLength: number;
  originalByteLength?: number;
  width?: number;
  height?: number;
  contentHash?: string;
}

export interface SavedPhotoResult {
  mimeType: string;
  byteLength: number;
  originalByteLength: number;
  width: number;
  height: number;
  contentHash: string;
  savedAt: string;
}

function openDb(): Promise<IDBDatabase> {
  return new Promise((resolve, reject) => {
    if (typeof indexedDB === "undefined") {
      reject(new Error("IndexedDB unavailable"));
      return;
    }

    const request = indexedDB.open(DB_NAME, DB_VERSION);
    request.onerror = () => reject(request.error ?? new Error("IndexedDB open failed"));
    request.onsuccess = () => resolve(request.result);
    request.onupgradeneeded = () => {
      const db = request.result;
      if (!db.objectStoreNames.contains(STORE)) {
        db.createObjectStore(STORE, { keyPath: "entryId" });
      }
    };
  });
}

export async function savePhoto(
  entryId: string,
  blob: Blob,
  mimeType?: string,
  meta?: {
    originalByteLength?: number;
    width?: number;
    height?: number;
  },
): Promise<SavedPhotoResult> {
  const resolvedMime = mimeType ?? (blob.type || "image/jpeg");
  const contentHash = await hashPhotoBlob(blob);
  const savedAt = new Date().toISOString();
  const byteLength = blob.size;

  const db = await openDb();

  await new Promise<void>((resolve, reject) => {
    const tx = db.transaction(STORE, "readwrite");
    tx.oncomplete = () => {
      db.close();
      resolve();
    };
    tx.onerror = () => {
      db.close();
      reject(tx.error ?? new Error("Failed to save photo"));
    };

    tx.objectStore(STORE).put({
      entryId,
      blob,
      mimeType: resolvedMime,
      savedAt,
      byteLength,
      originalByteLength: meta?.originalByteLength,
      width: meta?.width,
      height: meta?.height,
      contentHash,
    } satisfies StoredPhotoRecord);
  });

  return {
    mimeType: resolvedMime,
    byteLength,
    originalByteLength: meta?.originalByteLength ?? byteLength,
    width: meta?.width ?? 0,
    height: meta?.height ?? 0,
    contentHash,
    savedAt,
  };
}

export async function getPhoto(
  entryId: string,
): Promise<StoredPhotoRecord | null> {
  if (typeof indexedDB === "undefined") return null;

  try {
    const db = await openDb();

    return new Promise((resolve, reject) => {
      const tx = db.transaction(STORE, "readonly");
      const request = tx.objectStore(STORE).get(entryId);

      request.onsuccess = () => {
        db.close();
        const row = request.result as StoredPhotoRecord | undefined;
        if (!row?.blob) {
          resolve(null);
          return;
        }
        resolve(row);
      };

      request.onerror = () => {
        db.close();
        reject(request.error ?? new Error("Failed to load photo"));
      };
    });
  } catch {
    return null;
  }
}

export async function deletePhoto(entryId: string): Promise<void> {
  if (typeof indexedDB === "undefined") return;

  try {
    const db = await openDb();
    await new Promise<void>((resolve, reject) => {
      const tx = db.transaction(STORE, "readwrite");
      tx.oncomplete = () => {
        db.close();
        resolve();
      };
      tx.onerror = () => {
        db.close();
        reject(tx.error ?? new Error("Failed to delete photo"));
      };
      tx.objectStore(STORE).delete(entryId);
    });
  } catch {
    // ignore
  }
}

export async function clearAllPhotos(): Promise<void> {
  if (typeof indexedDB === "undefined") return;

  try {
    const db = await openDb();
    await new Promise<void>((resolve, reject) => {
      const tx = db.transaction(STORE, "readwrite");
      tx.oncomplete = () => {
        db.close();
        resolve();
      };
      tx.onerror = () => {
        db.close();
        reject(tx.error ?? new Error("Failed to clear photos"));
      };
      tx.objectStore(STORE).clear();
    });
  } catch {
    // ignore
  }
}

export async function listPhotoEntryIds(): Promise<string[]> {
  if (typeof indexedDB === "undefined") return [];

  try {
    const db = await openDb();
    return new Promise((resolve, reject) => {
      const tx = db.transaction(STORE, "readonly");
      const request = tx.objectStore(STORE).getAllKeys();
      request.onsuccess = () => {
        db.close();
        resolve((request.result as string[]) ?? []);
      };
      request.onerror = () => {
        db.close();
        reject(request.error ?? new Error("Failed to list photos"));
      };
    });
  } catch {
    return [];
  }
}

export async function countPhotos(): Promise<number> {
  const ids = await listPhotoEntryIds();
  return ids.length;
}

export async function photoExists(entryId: string): Promise<boolean> {
  const photo = await getPhoto(entryId);
  return Boolean(photo?.blob?.size);
}
