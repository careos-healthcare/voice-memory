import { trackLocalEvent } from "@/lib/local-analytics";
import type {
  StoredTestimonial,
  TestimonialEmotionalCategory,
  TestimonialStatus,
} from "@/types/social-proof";

const STORAGE_KEY = "voicememory_testimonial_reviews";

export const TESTIMONIAL_FORBIDDEN_PHRASES = [
  "life-changing",
  "transformed me",
  "changed everything",
  "productivity boost",
  "best version of myself",
  "healing system",
  "breakthrough ai",
  "optimized my life",
  "never miss a reflection",
  "game changer",
  "users like you",
  "join thousands",
  "don't miss out",
] as const;

export const TESTIMONIAL_PREFERRED_PHRASES = [
  "quieter",
  "returned to",
  "remembered later",
  "came back to",
  "sounded different",
  "clearer later",
] as const;

function isBrowser(): boolean {
  return typeof window !== "undefined";
}

function readAll(): StoredTestimonial[] {
  if (!isBrowser()) return [];
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (!raw) return [];
    const parsed = JSON.parse(raw) as StoredTestimonial[];
    return Array.isArray(parsed) ? parsed : [];
  } catch {
    return [];
  }
}

function writeAll(rows: StoredTestimonial[]): void {
  if (!isBrowser()) return;
  localStorage.setItem(STORAGE_KEY, JSON.stringify(rows.slice(-200)));
}

export function findForbiddenTestimonialPhrase(text: string): string | null {
  const lower = text.toLowerCase();
  for (const phrase of TESTIMONIAL_FORBIDDEN_PHRASES) {
    if (lower.includes(phrase)) return phrase;
  }
  if (/\bcoach(ing)?\b/i.test(text)) return "coaching";
  if (/\bproductivity\b/i.test(text)) return "productivity";
  return null;
}

export function isOverdramaticTestimonial(text: string): boolean {
  return (
    findForbiddenTestimonialPhrase(text) !== null ||
    /\b(completely|totally|everything|never|always|miracle|revolutionary)\b/i.test(text)
  );
}

export function upsertTestimonialCandidate(input: {
  text: string;
  emotionalCategory: TestimonialEmotionalCategory;
  sourceCallbackIds?: string[];
  retentionLinkages?: string[];
}): StoredTestimonial {
  const trimmed = input.text.trim().slice(0, 280);
  const now = new Date().toISOString();
  const forbidden = findForbiddenTestimonialPhrase(trimmed);
  const status: TestimonialStatus = forbidden || isOverdramaticTestimonial(trimmed) ? "rejected" : "pending";
  const reason = forbidden
    ? `Forbidden phrasing: ${forbidden}`
    : isOverdramaticTestimonial(trimmed)
      ? "Overdramatic or overclaimed wording"
      : undefined;

  const existing = readAll().find(
    (row) => row.text.toLowerCase() === trimmed.toLowerCase(),
  );

  const row: StoredTestimonial = {
    id: existing?.id ?? `testimonial-${crypto.randomUUID()}`,
    text: trimmed,
    emotionalCategory: input.emotionalCategory,
    status: existing?.status === "approved" ? "approved" : status,
    reason: existing?.status === "approved" ? existing.reason : reason,
    sourceCallbackIds: input.sourceCallbackIds ?? existing?.sourceCallbackIds ?? [],
    retentionLinkages: input.retentionLinkages ?? existing?.retentionLinkages ?? [],
    createdAt: existing?.createdAt ?? now,
    updatedAt: now,
  };

  const rows = readAll().filter((item) => item.id !== row.id);
  rows.unshift(row);
  writeAll(rows);
  return row;
}

export function setTestimonialStatus(
  id: string,
  status: TestimonialStatus,
  reason?: string,
): StoredTestimonial | null {
  const rows = readAll();
  const index = rows.findIndex((row) => row.id === id);
  if (index < 0) return null;

  if (status === "approved" && isOverdramaticTestimonial(rows[index].text)) {
    return null;
  }

  rows[index] = {
    ...rows[index],
    status,
    reason: reason ?? rows[index].reason,
    updatedAt: new Date().toISOString(),
  };
  writeAll(rows);
  trackLocalEvent("testimonial_review_updated", { id, status });
  return rows[index];
}

export function readApprovedTestimonials(): StoredTestimonial[] {
  return readAll().filter((row) => row.status === "approved");
}

export function readRejectedTestimonials(): StoredTestimonial[] {
  return readAll().filter((row) => row.status === "rejected");
}

export function readAllTestimonials(): StoredTestimonial[] {
  return readAll();
}

export function exportAnonymizedTestimonials(): Array<{
  text: string;
  emotionalCategory: TestimonialEmotionalCategory;
}> {
  return readApprovedTestimonials().map((row) => ({
    text: row.text,
    emotionalCategory: row.emotionalCategory,
  }));
}
