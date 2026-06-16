export type ArchiveProductSurfaceId =
  | "archive"
  | "discover"
  | "blind_spots"
  | "evidence"
  | "timeline"
  | "search"
  | "memory"
  | "theories"
  | "updates"
  | "journal"
  | "record"
  | "account"
  | "export"
  | "pricing"
  | "other";

export type ArchiveProductSurfaceRole = "primary" | "supporting" | "utility" | "internal";

export interface ArchiveProductSurfaceQuestion {
  surfaceId: ArchiveProductSurfaceId;
  route: string;
  productQuestion: string | null;
  role: ArchiveProductSurfaceRole;
  utilityOnly: boolean;
  helpsArchiveUnderstanding: boolean;
}

export const ARCHIVE_PRODUCT_ONE_LINER =
  "It keeps track of what my archive currently believes about me and how that changes over time.";

export const ARCHIVE_PRODUCT_QUESTIONS: Record<
  ArchiveProductSurfaceId,
  string | null
> = {
  archive: "What does my archive believe?",
  discover: "What changed?",
  blind_spots: "Why does the archive believe this?",
  evidence: "What supports this belief?",
  timeline: "How has this changed?",
  search: "What evidence exists?",
  memory: null,
  theories: null,
  updates: "What changed?",
  journal: null,
  record: null,
  account: null,
  export: null,
  pricing: null,
  other: null,
};

export function productQuestionForRoute(pathname: string): ArchiveProductSurfaceQuestion {
  const path = pathname.split("?")[0] ?? pathname;

  if (path.startsWith("/internal") || path.startsWith("/debug")) {
    return {
      surfaceId: "other",
      route: path,
      productQuestion: null,
      role: "internal",
      utilityOnly: false,
      helpsArchiveUnderstanding: false,
    };
  }

  let surfaceId: ArchiveProductSurfaceId = "other";
  if (path === "/archive-belief" || path === "/archive") surfaceId = "archive";
  else if (path.startsWith("/discover")) surfaceId = "discover";
  else if (path.startsWith("/blind-spots")) surfaceId = "blind_spots";
  else if (path.startsWith("/timeline") || path.startsWith("/feelings-timeline")) {
    surfaceId = "timeline";
  } else if (path.startsWith("/search")) surfaceId = "search";
  else if (path.startsWith("/memory") || path.startsWith("/entry/")) surfaceId = "memory";
  else if (path.startsWith("/theories")) surfaceId = "theories";
  else if (path.startsWith("/updates")) surfaceId = "updates";
  else if (path.startsWith("/journal")) surfaceId = "journal";
  else if (path === "/" || path.startsWith("/record")) surfaceId = "record";
  else if (path.startsWith("/account")) surfaceId = "account";
  else if (path.startsWith("/export")) surfaceId = "export";
  else if (path.startsWith("/pricing")) surfaceId = "pricing";

  const productQuestion = ARCHIVE_PRODUCT_QUESTIONS[surfaceId];
  const utilityOnly = productQuestion === null && surfaceId !== "record";

  const role: ArchiveProductSurfaceRole =
    surfaceId === "archive"
      ? "primary"
      : surfaceId === "discover" ||
          surfaceId === "blind_spots" ||
          surfaceId === "timeline" ||
          surfaceId === "search"
        ? "supporting"
        : utilityOnly
          ? "utility"
          : surfaceId === "record"
            ? "supporting"
            : "utility";

  return {
    surfaceId,
    route: path,
    productQuestion,
    role,
    utilityOnly,
    helpsArchiveUnderstanding: productQuestion !== null,
  };
}

export function howDoesThisHelpArchive(pathname: string): string {
  const q = productQuestionForRoute(pathname);
  if (q.productQuestion) {
    return q.productQuestion;
  }
  if (q.utilityOnly) {
    return "Utility — supports the archive without being the archive.";
  }
  return "Supporting capture or account — not the archive readout.";
}
