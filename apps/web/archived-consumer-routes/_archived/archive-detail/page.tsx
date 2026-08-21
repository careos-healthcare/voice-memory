"use client";

import { ArchiveBeliefHeader } from "@/archived-components/_archived/archive/ArchiveBeliefHeader";
import { ArchiveDetailHub } from "@/archived-components/_archived/archive/ArchiveDetailHub";
import { ArchiveActionArea } from "@/components/layout/ArchiveActionArea";
import { ArchivePageBlueprint } from "@/components/layout/ArchivePageBlueprint";
import { PrimaryMain } from "@/components/layout/PrimaryMain";
import { SiteHeader } from "@/components/SiteHeader";
import { ARCHIVE_SPACE } from "@/lib/design/archive-spacing";
import { ARCHIVE_COPY_RESTRAINT, ARCHIVE_SURFACE_EYEBROWS } from "@/lib/design/archive-copy-restraint";

export default function ArchiveDetailPage() {
  return (
    <div className="min-h-screen bg-zinc-950">
      <div className="mx-auto max-w-3xl px-4 pb-24 sm:px-6">
        <SiteHeader />
        <PrimaryMain className="mt-2">
          <ArchivePageBlueprint
            surface="archive_detail"
            identity={{
              eyebrow: ARCHIVE_SURFACE_EYEBROWS.detail,
              title: ARCHIVE_COPY_RESTRAINT.detail.headline,
              lead: ARCHIVE_COPY_RESTRAINT.detail.support,
            }}
            currentArchiveState={<ArchiveBeliefHeader className={ARCHIVE_SPACE.sm} compact />}
            mainContent={<ArchiveDetailHub variant="page" />}
            actionArea={
              <ArchiveActionArea
                primary={{ label: "Open Archive", href: "/archive-belief" }}
                secondary={{ label: "Archive Activity", href: "/discover" }}
              />
            }
          />
        </PrimaryMain>
      </div>
    </div>
  );
}
