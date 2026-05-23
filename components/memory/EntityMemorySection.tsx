import Link from "next/link";
import { ArrowRight } from "lucide-react";

import { Badge } from "@/components/ui/badge";
import {
  formatEntityDateRange,
  formatEntityTypeLabel,
  type TrackedEntity,
} from "@/lib/entity-memory";

interface EntityMemorySectionProps {
  title: string;
  subtitle: string;
  entities: TrackedEntity[];
  emptyLabel: string;
}

export function EntityMemorySection({
  title,
  subtitle,
  entities,
  emptyLabel,
}: EntityMemorySectionProps) {
  return (
    <section className="space-y-8">
      <div>
        <h2 className="text-sm font-normal text-zinc-500">{title}</h2>
        {subtitle ? <p className="mt-1 text-xs text-zinc-600">{subtitle}</p> : null}
      </div>
      {entities.length === 0 ? (
        <p className="text-sm text-zinc-600">{emptyLabel}</p>
      ) : (
        <ul className="space-y-10">
          {entities.map((entity) => (
            <li key={entity.id} className="space-y-3 px-1 py-1">
              <div className="flex items-start justify-between gap-3">
                <div className="min-w-0 flex-1">
                  <div className="flex flex-wrap items-center gap-2">
                    <p className="font-normal capitalize text-zinc-200">{entity.name}</p>
                    <Badge variant="secondary" className="text-[10px] font-normal">
                      {formatEntityTypeLabel(entity.type)}
                    </Badge>
                  </div>
                  <p className="mt-2 text-xs text-zinc-500">
                    You mentioned this {entity.mentionCount} time
                    {entity.mentionCount === 1 ? "" : "s"}
                  </p>
                  <p className="mt-1 text-xs text-zinc-600">{formatEntityDateRange(entity)}</p>
                  {entity.relatedMoods.length > 0 ? (
                    <div className="mt-3 flex flex-wrap gap-1.5">
                      {entity.relatedMoods.map((mood) => (
                        <span
                          key={mood}
                          className="rounded-full bg-white/[0.03] px-2 py-0.5 text-[10px] capitalize text-zinc-500"
                        >
                          {mood}
                        </span>
                      ))}
                    </div>
                  ) : null}
                  {entity.relatedThemes.length > 0 ? (
                    <p className="mt-2 line-clamp-2 text-xs leading-relaxed text-zinc-600">
                      {entity.relatedThemes.join(", ")}
                    </p>
                  ) : null}
                </div>
              </div>

              <div className="flex flex-wrap gap-2 pt-1">
                {entity.sampleEntryIds.map((entryId) => (
                  <Link
                    key={entryId}
                    href={`/entry/${entryId}`}
                    className="inline-flex items-center gap-1 text-xs text-zinc-500 transition-colors hover:text-zinc-300"
                  >
                    View entry
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
      )}
    </section>
  );
}
