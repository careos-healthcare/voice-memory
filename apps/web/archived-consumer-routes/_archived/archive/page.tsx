import { ArchivePageClient } from "@/app/archive/ArchivePageClient";
import { MotionPageTitle } from "@/archived-components/_archived/motion/MotionPage";
import { PrimaryMain } from "@/components/layout/PrimaryMain";
import { SiteHeader } from "@/components/SiteHeader";

export default function ArchivePage() {
  return (
    <div className="min-h-screen bg-zinc-950">
      <div className="mx-auto max-w-3xl px-4 pb-24 sm:px-6">
        <SiteHeader />
        <PrimaryMain>
        <MotionPageTitle title="Archive" />
        <ArchivePageClient />
        </PrimaryMain>
      </div>
    </div>
  );
}
