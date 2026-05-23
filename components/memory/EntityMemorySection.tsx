import Link from "next/link";
import { ArrowRight } from "lucide-react";

import { Badge } from "@/components/ui/badge";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
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
    <Card>
      <CardHeader className="pb-2">
        <CardTitle className="text-base">{title}</CardTitle>
        <p className="text-xs text-zinc-500">{subtitle}</p>
      </CardHeader>
      <CardContent>
        {entities.length === 0 ? (
          <p className="text-sm text-zinc-500">{emptyLabel}</p>
        ) : (
          <ul className="space-y-3">
            {entities.map((entity) => (
              <li
                key={entity.id}
                className="rounded-2xl border border-white/10 bg-white/[0.02] p-4"
              >
                <div className="flex items-start justify-between gap-3">
                  <div className="min-w-0 flex-1">
                    <div className="flex flex-wrap items-center gap-2">
                      <p className="font-medium capitalize text-white">
                        {entity.name}
                      </p>
                      <Badge variant="secondary" className="text-[10px]">
                        {formatEntityTypeLabel(entity.type)}
                      </Badge>
                    </div>
                    <p className="mt-1 text-xs text-violet-300">
                      You mentioned this {entity.mentionCount} time
                      {entity.mentionCount === 1 ? "" : "s"}
                    </p>
                    <p className="mt-1 text-xs text-zinc-600">
                      {formatEntityDateRange(entity)}
                    </p>
                    {entity.relatedMoods.length > 0 ? (
                      <div className="mt-2 flex flex-wrap gap-1.5">
                        {entity.relatedMoods.map((mood) => (
                          <span
                            key={mood}
                            className="rounded-full bg-white/5 px-2 py-0.5 text-[10px] capitalize text-zinc-400"
                          >
                            {mood}
                          </span>
                        ))}
                      </div>
                    ) : null}
                    {entity.relatedThemes.length > 0 ? (
                      <p className="mt-2 line-clamp-2 text-xs text-zinc-500">
                        Themes · {entity.relatedThemes.join(", ")}
                      </p>
                    ) : null}
                  </div>
                </div>

                <div className="mt-3 flex flex-wrap gap-2 border-t border-white/5 pt-3">
                  {entity.sampleEntryIds.map((entryId) => (
                    <Link
                      key={entryId}
                      href={`/entry/${entryId}`}
                      className="inline-flex items-center gap-1 rounded-full bg-violet-500/10 px-3 py-1.5 text-xs text-violet-200 transition-colors hover:bg-violet-500/20"
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
      </CardContent>
    </Card>
  );
}
