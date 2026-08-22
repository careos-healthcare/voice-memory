import type {
  DistributionTestimonial,
  TransformationMomentType,
} from "@/types/distribution";

export const DISTRIBUTION_TESTIMONIALS_KEY = "voicememory_distribution_testimonials";
export const TESTIMONIAL_CAPTURE_QUESTION = "What surprised you most?";

const MAX_TESTIMONIALS = 60;

const MAJOR_MOMENT_TYPES: TransformationMomentType[] = [
  "first_belief",
  "belief_change",
  "belief_challenged",
  "archive_changed_while_away",
  "first_contradiction",
  "first_strong_attachment",
  "first_return_after_archive_change",
];

function isBrowser(): boolean {
  return typeof window !== "undefined";
}

function newId(): string {
  if (typeof crypto !== "undefined" && typeof crypto.randomUUID === "function") {
    return `dt-${crypto.randomUUID()}`;
  }
  return `dt-${Date.now()}`;
}

export function readDistributionTestimonials(): DistributionTestimonial[] {
  if (!isBrowser()) return [];
  try {
    const raw = localStorage.getItem(DISTRIBUTION_TESTIMONIALS_KEY);
    if (!raw) return [];
    const parsed = JSON.parse(raw) as DistributionTestimonial[];
    return Array.isArray(parsed) ? parsed : [];
  } catch {
    return [];
  }
}

function writeDistributionTestimonials(rows: DistributionTestimonial[]): void {
  if (!isBrowser()) return;
  localStorage.setItem(
    DISTRIBUTION_TESTIMONIALS_KEY,
    JSON.stringify(rows.slice(-MAX_TESTIMONIALS)),
  );
}

export function isMajorTestimonialMoment(
  type: TransformationMomentType,
): boolean {
  return MAJOR_MOMENT_TYPES.includes(type);
}

export function saveDistributionTestimonial(input: {
  momentType: TransformationMomentType;
  text: string;
  rating: DistributionTestimonial["rating"];
}): DistributionTestimonial {
  const trimmed = input.text.trim().slice(0, 600);
  const row: DistributionTestimonial = {
    id: newId(),
    momentType: input.momentType,
    text: trimmed,
    rating: input.rating,
    capturedAt: new Date().toISOString(),
  };
  const rows = readDistributionTestimonials();
  writeDistributionTestimonials([...rows, row]);
  return row;
}

export function hasTestimonialForMoment(
  type: TransformationMomentType,
): boolean {
  return readDistributionTestimonials().some((r) => r.momentType === type);
}

export function clearDistributionTestimonialsForEval(): void {
  if (!isBrowser()) return;
  localStorage.removeItem(DISTRIBUTION_TESTIMONIALS_KEY);
}
