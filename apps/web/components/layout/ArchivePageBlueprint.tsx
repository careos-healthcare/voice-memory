"use client";

import type { ReactNode } from "react";

import { ARCHIVE_SPACE } from "@/lib/design/archive-spacing";
import { ARCHIVE_TYPO } from "@/lib/design/archive-typography";
import {
  ARCHIVE_BLUEPRINT_SECTION_ORDER,
  blueprintSectionToGrammar,
  type ArchiveBlueprintSectionId,
} from "@/lib/design/archive-page-grammar";
import { cn } from "@/lib/utils";

export type ArchiveExperienceSurface =
  | "archive"
  | "discover"
  | "blind_spots"
  | "memory"
  | "changes"
  | "account"
  | "archive_detail";

export type ArchivePageIdentity = {
  eyebrow: string;
  title: string;
  lead?: string;
  subheadline?: string;
};

type ArchivePageBlueprintProps = {
  surface: ArchiveExperienceSurface;
  identity: ArchivePageIdentity;
  currentArchiveState?: ReactNode;
  whatChanged?: ReactNode;
  mainContent: ReactNode;
  supportingContent?: ReactNode;
  actionArea?: ReactNode;
  className?: string;
};

function BlueprintSection({
  section,
  gravity,
  children,
  className,
}: {
  section: ArchiveBlueprintSectionId;
  gravity?: string;
  children: ReactNode;
  className?: string;
}) {
  if (!children) return null;
  const grammar = blueprintSectionToGrammar(section);
  return (
    <section
      data-archive-section={section}
      data-archive-grammar-section={grammar}
      data-gravity={gravity ?? grammar}
      className={className}
    >
      {children}
    </section>
  );
}

/**
 * Shared structure for Archive, Discover, Archive Insight, Reflection Log, and Changes.
 */
export function ArchivePageBlueprint({
  surface,
  identity,
  currentArchiveState,
  whatChanged,
  mainContent,
  supportingContent,
  actionArea,
  className,
}: ArchivePageBlueprintProps) {
  return (
    <div
      className={cn(ARCHIVE_SPACE.mainStack, className)}
      data-archive-surface={surface}
      data-archive-blueprint-sections={ARCHIVE_BLUEPRINT_SECTION_ORDER.join(",")}
      data-testid="archive-page-blueprint"
    >
      <BlueprintSection section="identity" gravity="identity">
        <p className={ARCHIVE_TYPO.eyebrow}>{identity.eyebrow}</p>
        <h1 className={cn(ARCHIVE_TYPO.pageTitle, ARCHIVE_SPACE.sm)}>{identity.title}</h1>
        {identity.subheadline ? (
          <p className={cn(ARCHIVE_TYPO.body, "text-violet-100/70", ARCHIVE_SPACE.sm)}>
            {identity.subheadline}
          </p>
        ) : null}
        {identity.lead ? (
          <p className={cn(ARCHIVE_TYPO.body, ARCHIVE_SPACE.sm)}>{identity.lead}</p>
        ) : null}
      </BlueprintSection>

      <BlueprintSection section="belief" gravity="belief" className={ARCHIVE_SPACE.sectionBreath}>
        {currentArchiveState}
      </BlueprintSection>

      <BlueprintSection section="change" gravity="change" className={ARCHIVE_SPACE.sectionBreath}>
        {whatChanged}
      </BlueprintSection>

      <BlueprintSection section="main" gravity="timeline" className={ARCHIVE_SPACE.sectionBreath}>
        {mainContent}
      </BlueprintSection>

      <BlueprintSection
        section="supporting"
        gravity="utilities"
        className={ARCHIVE_SPACE.sectionBreath}
      >
        {supportingContent}
      </BlueprintSection>

      <BlueprintSection section="action" gravity="utilities">
        {actionArea}
      </BlueprintSection>
    </div>
  );
}
