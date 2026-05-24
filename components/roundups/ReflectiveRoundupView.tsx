"use client";

import Link from "next/link";

import { RevisitEntryLink } from "@/components/navigation/RevisitEntryLink";
import type { KeyPiecesReport, ReflectiveRoundup } from "@/types/reflective-roundup";

function KeyPiecesSection({ report }: { report: KeyPiecesReport }) {
  if (!report.hasData) return null;

  return (
    <section className="space-y-8 border-t border-white/[0.06] pt-14">
      <h2 className="text-xs uppercase tracking-[0.18em] text-zinc-600">Worth noticing</h2>
      <ul className="space-y-10">
        {report.items.map((item) => (
          <li key={item.id} className="space-y-3">
            <p className="text-[15px] font-normal leading-[1.75] text-zinc-300/95">{item.text}</p>
            <RevisitEntryLink
              entryId={item.entryId}
              source="memory_note"
              noteId={item.id}
              noteText={item.text}
              className="text-xs text-zinc-600/90 transition-colors hover:text-zinc-400"
            >
              Source entry
            </RevisitEntryLink>
          </li>
        ))}
      </ul>
    </section>
  );
}

export function ReflectiveRoundupView({
  roundup,
  keyPieces,
}: {
  roundup: ReflectiveRoundup;
  keyPieces?: KeyPiecesReport | null;
}) {
  const hasLines = roundup.hasData && roundup.lines.length > 0;
  const hasKeyPieces = keyPieces?.hasData ?? false;

  if (!hasLines && !hasKeyPieces) {
    return (
      <p className="text-sm leading-relaxed text-zinc-500">
        Nothing to gather from this period yet.
      </p>
    );
  }

  return (
    <div className="space-y-14">
      {hasLines ? (
        <div className="space-y-14">
          {roundup.lines.map((line) => (
            <article key={line.id} className="space-y-4">
              <p className="text-[15px] font-normal leading-[1.75] text-zinc-300/95">{line.text}</p>
              {line.entryIds.length > 0 ? (
                <div className="flex flex-wrap gap-x-4 gap-y-1 text-xs text-zinc-600/90">
                  {line.entryIds.map((entryId, index) => (
                    <RevisitEntryLink
                      key={`${line.id}-${entryId}`}
                      entryId={entryId}
                      source="memory_note"
                      noteId={line.id}
                      noteText={line.text}
                      className="transition-colors hover:text-zinc-400"
                    >
                      {line.entryIds.length === 1 ? "Related entry" : `Related entry ${index + 1}`}
                    </RevisitEntryLink>
                  ))}
                </div>
              ) : null}
            </article>
          ))}
        </div>
      ) : null}

      {keyPieces ? <KeyPiecesSection report={keyPieces} /> : null}
    </div>
  );
}

export function ReflectiveRoundupIndex({
  items,
}: {
  items: Array<{
    period: ReflectiveRoundup["period"];
    previewLine?: string;
    hasData: boolean;
  }>;
}) {
  if (items.length === 0) {
    return (
      <p className="text-sm leading-relaxed text-zinc-500">
        Record a few reflections and roundups will appear here.
      </p>
    );
  }

  return (
    <ul className="space-y-10">
      {items.map((item) => (
        <li key={item.period.slug}>
          <Link href={`/roundups/${item.period.slug}`} className="group block space-y-2">
            <p className="text-xs uppercase tracking-[0.18em] text-zinc-600">
              {item.period.kind === "weekly"
                ? "Weekly"
                : item.period.kind === "monthly"
                  ? "Monthly"
                  : "Period"}
            </p>
            <p className="text-lg font-medium text-zinc-200 transition-colors group-hover:text-white">
              {item.period.label}
            </p>
            {item.previewLine ? (
              <p className="text-sm leading-relaxed text-zinc-500">{item.previewLine}</p>
            ) : null}
          </Link>
        </li>
      ))}
    </ul>
  );
}
