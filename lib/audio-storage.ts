const DB_NAME = "voicememory_audio";
const DB_VERSION = 1;
const STORE = "recordings";

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

export async function saveAudio(
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
      reject(tx.error ?? new Error("Failed to save audio"));
    };

    tx.objectStore(STORE).put({
      entryId,
      blob,
      mimeType: mimeType ?? (blob.type || "audio/webm"),
      savedAt: new Date().toISOString(),
    });
  });
}

export async function getAudio(
  entryId: string,
): Promise<{ blob: Blob; mimeType: string } | null> {
  if (typeof indexedDB === "undefined") return null;

  try {
    const db = await openDb();

    return new Promise((resolve, reject) => {
      const tx = db.transaction(STORE, "readonly");
      const request = tx.objectStore(STORE).get(entryId);

      request.onsuccess = () => {
        db.close();
        const row = request.result as
          | { blob: Blob; mimeType: string }
          | undefined;
        if (!row?.blob) {
          resolve(null);
          return;
        }
        resolve({ blob: row.blob, mimeType: row.mimeType });
      };

      request.onerror = () => {
        db.close();
        reject(request.error ?? new Error("Failed to load audio"));
      };
    });
  } catch {
    return null;
  }
}

export async function hasAudio(entryId: string): Promise<boolean> {
  const audio = await getAudio(entryId);
  return audio !== null;
}

export async function listAudioEntryIds(): Promise<string[]> {
  if (typeof indexedDB === "undefined") return [];

  try {
    const db = await openDb();

    return new Promise((resolve, reject) => {
      const tx = db.transaction(STORE, "readonly");
      const request = tx.objectStore(STORE).getAllKeys();

      request.onsuccess = () => {
        db.close();
        resolve(
          (request.result as IDBValidKey[])
            .filter((key): key is string => typeof key === "string")
            .sort(),
        );
      };

      request.onerror = () => {
        db.close();
        reject(request.error ?? new Error("Failed to list audio keys"));
      };
    });
  } catch {
    return [];
  }
}

export async function deleteAudio(entryId: string): Promise<void> {
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
        reject(tx.error ?? new Error("Failed to delete audio"));
      };
      tx.objectStore(STORE).delete(entryId);
    });
  } catch {
    // Best-effort cleanup
  }
}

export async function clearAllAudio(): Promise<void> {
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
        reject(tx.error ?? new Error("Failed to clear audio"));
      };
      tx.objectStore(STORE).clear();
    });
  } catch {
    // Best-effort
  }
}
