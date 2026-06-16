"use client";

import { buildArchiveExportPreview } from "@/lib/archive/archive-export-preview";
import { useClientHydrated } from "@/lib/hooks/use-client-hydrated";

export function ArchiveExportPreview({ className = "" }: { className?: string }) {
  const hydrated = useClientHydrated();
  if (!hydrated) return null;

  const preview = buildArchiveExportPreview();
  return (
    <section
      className={`rounded-2xl border border-violet-500/20 bg-violet-950/10 px-4 py-4 ${className}`}
      data-testid="archive-export-preview"
    >
      <h2 className="text-sm font-medium text-violet-100/90">What your export includes</h2>
      <p className="mt-1 text-xs text-zinc-500">{preview.lead}</p>
      <ul className="mt-3 space-y-2">
        {preview.sections.map((section) => (
          <li key={section.id} className="flex justify-between gap-4 text-sm">
            <span className="text-zinc-400">{section.label}</span>
            <span className="text-right text-zinc-500">{section.detail}</span>
          </li>
        ))}
      </ul>
    </section>
  );
}
