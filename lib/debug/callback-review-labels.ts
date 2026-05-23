import type { CallbackReviewLabel } from "@/types/callback-quality-review";

const REVIEWS_KEY = "voicememory_callback_reviews";

export interface StoredCallbackReview {
  callbackId: string;
  labels: CallbackReviewLabel[];
  updatedAt: string;
}

function isBrowser(): boolean {
  return typeof window !== "undefined";
}

function readAll(): StoredCallbackReview[] {
  if (!isBrowser()) return [];
  try {
    const raw = localStorage.getItem(REVIEWS_KEY);
    if (!raw) return [];
    const parsed = JSON.parse(raw) as StoredCallbackReview[];
    return Array.isArray(parsed) ? parsed : [];
  } catch {
    return [];
  }
}

function writeAll(reviews: StoredCallbackReview[]): void {
  if (!isBrowser()) return;
  localStorage.setItem(REVIEWS_KEY, JSON.stringify(reviews.slice(-500)));
}

export function getCallbackReviewLabels(callbackId: string): CallbackReviewLabel[] {
  return readAll().find((review) => review.callbackId === callbackId)?.labels ?? [];
}

export function setCallbackReviewLabels(
  callbackId: string,
  labels: CallbackReviewLabel[],
): void {
  const unique = [...new Set(labels)];
  const reviews = readAll().filter((review) => review.callbackId !== callbackId);
  if (unique.length > 0) {
    reviews.push({
      callbackId,
      labels: unique,
      updatedAt: new Date().toISOString(),
    });
  }
  writeAll(reviews);
}

export function toggleCallbackReviewLabel(
  callbackId: string,
  label: CallbackReviewLabel,
): CallbackReviewLabel[] {
  const current = getCallbackReviewLabels(callbackId);
  const next = current.includes(label)
    ? current.filter((item) => item !== label)
    : [...current, label];
  setCallbackReviewLabels(callbackId, next);
  return next;
}

export function readAllCallbackReviews(): StoredCallbackReview[] {
  return readAll();
}

export function countLabeledCallbacks(): number {
  return readAll().length;
}

export function clearCallbackReviews(): void {
  if (!isBrowser()) return;
  localStorage.removeItem(REVIEWS_KEY);
}
