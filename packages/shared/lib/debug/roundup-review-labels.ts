import type { RoundupReviewLabel } from "@/types/roundup-quality-review";

const REVIEWS_KEY = "voicememory_roundup_reviews";

export interface StoredRoundupReview {
  lineId: string;
  labels: RoundupReviewLabel[];
  updatedAt: string;
}

function isBrowser(): boolean {
  return typeof window !== "undefined";
}

function readAll(): StoredRoundupReview[] {
  if (!isBrowser()) return [];
  try {
    const raw = localStorage.getItem(REVIEWS_KEY);
    if (!raw) return [];
    const parsed = JSON.parse(raw) as StoredRoundupReview[];
    return Array.isArray(parsed) ? parsed : [];
  } catch {
    return [];
  }
}

function writeAll(reviews: StoredRoundupReview[]): void {
  if (!isBrowser()) return;
  localStorage.setItem(REVIEWS_KEY, JSON.stringify(reviews.slice(-800)));
}

export function getRoundupReviewLabels(lineId: string): RoundupReviewLabel[] {
  return readAll().find((review) => review.lineId === lineId)?.labels ?? [];
}

export function setRoundupReviewLabels(lineId: string, labels: RoundupReviewLabel[]): void {
  const unique = [...new Set(labels)];
  const reviews = readAll().filter((review) => review.lineId !== lineId);
  if (unique.length > 0) {
    reviews.push({
      lineId,
      labels: unique,
      updatedAt: new Date().toISOString(),
    });
  }
  writeAll(reviews);
}

export function toggleRoundupReviewLabel(
  lineId: string,
  label: RoundupReviewLabel,
): RoundupReviewLabel[] {
  const current = getRoundupReviewLabels(lineId);
  const next = current.includes(label)
    ? current.filter((item) => item !== label)
    : [...current, label];
  setRoundupReviewLabels(lineId, next);
  return next;
}

export function readAllRoundupReviews(): StoredRoundupReview[] {
  return readAll();
}
