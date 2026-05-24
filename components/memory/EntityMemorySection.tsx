import Link from "next/link";
import { ArrowRight } from "lucide-react";

import {
  formatEntityDateRange,
  type TrackedEntity,
} from "@/lib/entity-memory";

interface EntityMemorySectionProps {
  title?: string;
  entities: TrackedEntity[];
  emptyLabel?: string;
}

export function EntityMemorySection({
  title,
  entities,
  emptyLabel = "",
}: EntityMemorySectionProps) {
  if (entities.length === 0) {
    return emptyLabel ? <p className="text-sm text-zinc-600">{emptyLabel}</p> : null;
  }

  return (
    <section className="space-y-8">
      {title ? (
        <h2 className="text-sm font-normal text-zinc-500">{title}</h2>
      ) : null}
      <ul className="space-y-10">
        {entities.map((entity) => (
          <li key={entity.id} className="space-y-3 px-1 py-1">
            <div className="min-w-0 flex-1">
              <p className="font-normal capitalize text-zinc-200">{entity.name}</p>
              <p className="mt-2 text-xs text-zinc-500">
                You mentioned this {entity.mentionCount} time
                {entity.mentionCount === 1 ? "" : "s"}
              </p>
              <p className="mt-1 text-xs text-zinc-600">{formatEntityDateRange(entity)}</p>
            </div>

            <div className="flex flex-wrap gap-2 pt-1">
              {entity.sampleEntryIds.map((entryId) => (
                <Link
                  key={entryId}
                  href={`/entry/${entryId}`}
                  className="inline-flex items-center gap-1 text-xs text-zinc-500 transition-colors hover:text-zinc-300"
                >
                  Open
                  <ArrowRight className="h-3 w-3" />
                </Link>
              ))}
              {entity.entryIds.length > entity.sampleEntryIds.length ? (
                <span className="self-center text-[10px] text-zinc-600">
                  +{entity.entryIds.length - entity.sampleEntryIds.length} more
                </span>
              ) : null}
            </div>
          </li>
        ))}
      </ul>
    </section>
  );
}
