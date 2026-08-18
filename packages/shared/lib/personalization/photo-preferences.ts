const PHOTO_ENABLED_KEY = "voicememory_photo_attachments_enabled";

function isBrowser(): boolean {
  return typeof window !== "undefined";
}

export function isPhotoAttachmentEnabled(): boolean {
  if (!isBrowser()) return true;
  return localStorage.getItem(PHOTO_ENABLED_KEY) !== "0";
}

export function setPhotoAttachmentEnabled(enabled: boolean): void {
  if (!isBrowser()) return;
  if (enabled) {
    localStorage.removeItem(PHOTO_ENABLED_KEY);
  } else {
    localStorage.setItem(PHOTO_ENABLED_KEY, "0");
  }
  window.dispatchEvent(new CustomEvent("voicememory:photo-preferences"));
}
