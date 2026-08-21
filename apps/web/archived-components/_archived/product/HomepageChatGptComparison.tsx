import { ArchiveUniquenessPanel } from "@/archived-components/_archived/archive/ArchiveUniquenessPanel";
import { HOMEPAGE_ARCHIVE_DIFFERENTIATION } from "@/lib/product/product-clarity-copy";

export function HomepageChatGptComparison() {
  return (
    <div
      className="mx-auto mt-8 max-w-md space-y-4"
      data-testid="homepage-archive-differentiation"
    >
      <p
        className="text-sm leading-relaxed text-zinc-300"
        data-testid="homepage-chatgpt-differentiation"
      >
        {HOMEPAGE_ARCHIVE_DIFFERENTIATION.chatGptDifferentiation}
      </p>
      <ArchiveUniquenessPanel variant="compact" />
      <p className="text-sm leading-relaxed text-zinc-400">
        {HOMEPAGE_ARCHIVE_DIFFERENTIATION.archiveGrowth}
      </p>
      <p className="text-xs leading-relaxed text-zinc-600">
        {HOMEPAGE_ARCHIVE_DIFFERENTIATION.complement}
      </p>
    </div>
  );
}
