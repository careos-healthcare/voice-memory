const DB_NAME = "voicememory_photos";
const DB_VERSION = 1;
const STORE = "attachments";

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
): Promise<void> {
  const db = await openDb();

  return new Promise((resolve, reject) => {
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
      mimeType: mimeType ?? (blob.type || "image/jpeg"),
      savedAt: new Date().toISOString(),
    });
  });
}

export async function getPhoto(
  entryId: string,
): Promise<{ blob: Blob; mimeType: string; savedAt: string } | null> {
  if (typeof indexedDB === "undefined") return null;

  try {
    const db = await openDb();

    return new Promise((resolve, reject) => {
      const tx = db.transaction(STORE, "readonly");
      const request = tx.objectStore(STORE).get(entryId);

      request.onsuccess = () => {
        db.close();
        const row = request.result as
          | { blob: Blob; mimeType: string; savedAt: string }
          | undefined;
        if (!row?.blob) {
          resolve(null);
          return;
        }
        resolve({ blob: row.blob, mimeType: row.mimeType, savedAt: row.savedAt });
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
