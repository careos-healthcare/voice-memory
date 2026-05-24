const DB_NAME = "voicememory_atmospheres";
const DB_VERSION = 1;
const STORE = "images";

export interface StoredAtmosphereRecord {
  entryId: string;
  blob: Blob;
  mimeType: string;
  savedAt: string;
  byteLength: number;
  width: number;
  height: number;
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

export async function saveAtmosphereImage(
  entryId: string,
  blob: Blob,
  meta: { width: number; height: number },
): Promise<void> {
  const db = await openDb();

  await new Promise<void>((resolve, reject) => {
    const tx = db.transaction(STORE, "readwrite");
    tx.oncomplete = () => {
      db.close();
      resolve();
    };
    tx.onerror = () => {
      db.close();
      reject(tx.error ?? new Error("Failed to save atmosphere"));
    };

    tx.objectStore(STORE).put({
      entryId,
      blob,
      mimeType: blob.type || "image/png",
      savedAt: new Date().toISOString(),
      byteLength: blob.size,
      width: meta.width,
      height: meta.height,
    } satisfies StoredAtmosphereRecord);
  });
}

export async function getAtmosphereImage(
  entryId: string,
): Promise<StoredAtmosphereRecord | null> {
  if (typeof indexedDB === "undefined") return null;

  try {
    const db = await openDb();

    return new Promise((resolve, reject) => {
      const tx = db.transaction(STORE, "readonly");
      const request = tx.objectStore(STORE).get(entryId);

      request.onsuccess = () => {
        db.close();
        const row = request.result as StoredAtmosphereRecord | undefined;
        if (!row?.blob) {
          resolve(null);
          return;
        }
        resolve(row);
      };

      request.onerror = () => {
        db.close();
        reject(request.error ?? new Error("Failed to load atmosphere"));
      };
    });
  } catch {
    return null;
  }
}

export async function deleteAtmosphereImage(entryId: string): Promise<void> {
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
        reject(tx.error ?? new Error("Failed to delete atmosphere"));
      };
      tx.objectStore(STORE).delete(entryId);
    });
  } catch {
    // ignore
  }
}

export async function clearAllAtmospheres(): Promise<void> {
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
        reject(tx.error ?? new Error("Failed to clear atmospheres"));
      };
      tx.objectStore(STORE).clear();
    });
  } catch {
    // ignore
  }
}
