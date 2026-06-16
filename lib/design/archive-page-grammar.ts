/**
 * Archive page grammar — every public archive surface is six sections in this order.
 */

export const PAGE_STRUCTURE = [
  "identity",
  "current_state",
  "change",
  "evidence",
  "supporting_context",
  "action",
] as const;

export type ArchiveGrammarSection = (typeof PAGE_STRUCTURE)[number];

/** Blueprint `data-archive-section` ids (legacy) mapped to grammar. */
export const BLUEPRINT_SECTION_TO_GRAMMAR = {
  identity: "identity",
  belief: "current_state",
  change: "change",
  main: "evidence",
  supporting: "supporting_context",
  action: "action",
} as const satisfies Record<string, ArchiveGrammarSection>;

export type ArchiveBlueprintSectionId = keyof typeof BLUEPRINT_SECTION_TO_GRAMMAR;

export const ARCHIVE_BLUEPRINT_SECTION_ORDER: ArchiveBlueprintSectionId[] = [
  "identity",
  "belief",
  "change",
  "main",
  "supporting",
  "action",
];

export type ArchiveExperienceSurfaceKey =
  | "archive"
  | "changes"
  | "reflection_log"
  | "account"
  | "archive_detail";

export type ArchiveSurfaceGrammarSpec = {
  surface: ArchiveExperienceSurfaceKey;
  route: string;
  sourceFiles: string[];
  /** Sections that must appear in DOM/source order (subset allowed if collapsed). */
  requiredSections: ArchiveGrammarSection[];
  firstVisible: ArchiveGrammarSection | "site_chrome";
  largestHeadingRole: "PageTitle" | "HeroTitle";
  primaryCtaLabel?: string;
};

export const ARCHIVE_SURFACE_GRAMMAR: ArchiveSurfaceGrammarSpec[] = [
  {
    surface: "archive",
    route: "/archive-belief",
    sourceFiles: ["app/archive-belief/page.tsx", "components/archive/EvidenceArchiveHome.tsx"],
    requiredSections: [
      "identity",
      "current_state",
      "evidence",
      "supporting_context",
      "action",
    ],
    firstVisible: "current_state",
    largestHeadingRole: "PageTitle",
    primaryCtaLabel: "Export my archive",
  },
  {
    surface: "changes",
    route: "/discover",
    sourceFiles: ["app/discover/page.tsx"],
    requiredSections: ["identity", "current_state", "change", "evidence", "action"],
    firstVisible: "current_state",
    largestHeadingRole: "PageTitle",
  },
  {
    surface: "reflection_log",
    route: "/memory",
    sourceFiles: ["app/memory/page.tsx"],
    requiredSections: [
      "identity",
      "current_state",
      "evidence",
      "supporting_context",
      "action",
    ],
    firstVisible: "current_state",
    largestHeadingRole: "PageTitle",
    primaryCtaLabel: "Open Archive",
  },
  {
    surface: "account",
    route: "/account",
    sourceFiles: ["app/account/page.tsx"],
    requiredSections: ["identity", "evidence", "supporting_context", "action"],
    firstVisible: "identity",
    largestHeadingRole: "PageTitle",
    primaryCtaLabel: "Back up now",
  },
  {
    surface: "archive_detail",
    route: "/archive-detail",
    sourceFiles: ["app/archive-detail/page.tsx"],
    requiredSections: ["current_state", "evidence"],
    firstVisible: "current_state",
    largestHeadingRole: "PageTitle",
  },
];

export function grammarSectionRank(section: ArchiveGrammarSection): number {
  return PAGE_STRUCTURE.indexOf(section);
}

export function assertGrammarSectionOrder(sections: ArchiveGrammarSection[]): boolean {
  let last = -1;
  for (const s of sections) {
    const idx = grammarSectionRank(s);
    if (idx < last) return false;
    last = idx;
  }
  return true;
}

export function blueprintSectionToGrammar(
  blueprint: ArchiveBlueprintSectionId,
): ArchiveGrammarSection {
  return BLUEPRINT_SECTION_TO_GRAMMAR[blueprint];
}

export function extractGrammarSectionsFromSource(source: string): ArchiveGrammarSection[] {
  const re = /data-archive-grammar-section=["']([a-z_]+)["']/g;
  const found: ArchiveGrammarSection[] = [];
  let match: RegExpExecArray | null;
  while ((match = re.exec(source)) !== null) {
    const id = match[1] as ArchiveGrammarSection;
    if (PAGE_STRUCTURE.includes(id)) found.push(id);
  }
  return found;
}

export function extractBlueprintSectionsFromSource(source: string): ArchiveBlueprintSectionId[] {
  const re = /data-archive-section=["']([a-z]+)["']/g;
  const found: ArchiveBlueprintSectionId[] = [];
  let match: RegExpExecArray | null;
  while ((match = re.exec(source)) !== null) {
    const id = match[1] as ArchiveBlueprintSectionId;
    if (id in BLUEPRINT_SECTION_TO_GRAMMAR) found.push(id);
  }
  return found;
}

export function grammarSectionsFromBlueprintSource(source: string): ArchiveGrammarSection[] {
  return extractBlueprintSectionsFromSource(source).map(blueprintSectionToGrammar);
}
