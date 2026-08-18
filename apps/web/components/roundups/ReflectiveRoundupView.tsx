"use client";

import type { ReactNode } from "react";
import Link from "next/link";

import { RevisitEntryLink } from "@/components/navigation/RevisitEntryLink";
import { RoundupContinuationActions } from "@/components/roundups/RoundupContinuationActions";
import { RoundupLineObservation } from "@/components/roundups/RoundupLineObservation";
import { ShareQuietlyButton } from "@/components/sharing/ShareQuietlyButton";
import { buildQuietShareCard, buildRoundupQuietShareCard } from "@/lib/sharing/quiet-sharing";
import { trackRoundupItemRevisited } from "@/lib/roundups/roundup-continuation";
import { trackRoundupIntentionLinkOpened } from "@/lib/roundups/roundup-observation";
import type {
  KeyPiece,
  KeyPiecesReport,
  ReflectiveRoundup,
  ReflectiveRoundupLine,
  RoundupContinuationItem,
  RoundupIntentionLink,
  RoundupIntentionLinksReport,
} from "@/types/reflective-roundup";

function toContinuationItem(
  input: Pick<RoundupContinuationItem, "id" | "text" | "entryId" | "kind">,
): RoundupContinuationItem {
  return input;
}

function RoundupSourceLink({
  item,
  entryId,
  periodSlug,
  children,
  className,
}: {
  item: RoundupContinuationItem;
  entryId: string;
  periodSlug?: string;
  children: ReactNode;
  className?: string;
}) {
  return (
    <RevisitEntryLink
      entryId={entryId}
      source="memory_note"
      noteId={item.id}
      noteText={item.text}
      className={className}
      onNavigate={() => trackRoundupItemRevisited(item, entryId, periodSlug)}
    >
      {children}
    </RevisitEntryLink>
  );
}

function IntentionLinkRow({
  link,
  periodSlug,
}: {
  link: RoundupIntentionLink;
  periodSlug?: string;
}) {
  const item = toContinuationItem({
    id: link.id,
    text: link.text,
    entryId: link.entryId,
    kind: "intention_link",
  });

  return (
    <li>
      <RoundupLineObservation
        itemId={link.id}
        text={link.text}
        signal="returned"
        periodSlug={periodSlug}
      >
        <p className="text-[15px] font-normal leading-[1.75] text-zinc-300/95">{link.text}</p>
        <RoundupContinuationActions item={item} periodSlug={periodSlug} />
        <ShareQuietlyButton
          card={buildQuietShareCard({
            id: `share-roundup-intention-${link.id}`,
            line: link.text,
            source: "roundup",
            sourceId: link.id,
            entryId: link.entryId,
          })}
        />
        <div className="flex flex-wrap gap-x-4 gap-y-1">
          <RoundupSourceLink
            item={item}
            entryId={link.entryId}
            periodSlug={periodSlug}
            className="text-xs text-zinc-600/90 transition-colors hover:text-zinc-400"
          >
            Source entry
          </RoundupSourceLink>
          <Link
            href="/intentions"
            className="text-xs text-zinc-600/90 transition-colors hover:text-zinc-400"
            onClick={() =>
              trackRoundupIntentionLinkOpened({
                itemId: link.id,
                text: link.text,
                intentionId: link.intentionId,
                periodSlug,
              })
            }
          >
            Long-term thread
          </Link>
        </div>
      </RoundupLineObservation>
    </li>
  );
}

function IntentionLinksSection({
  report,
  periodSlug,
}: {
  report: RoundupIntentionLinksReport;
  periodSlug?: string;
}) {
  if (!report.hasData) return null;

  const sections = [
    { title: "Still with you", items: report.stillWithYou },
    { title: "Changed shape", items: report.changedShape },
    { title: "Quieter this period", items: report.quieterThisPeriod },
  ].filter((section) => section.items.length > 0);

  return (
    <section className="space-y-10 border-t border-white/[0.06] pt-14">
      {sections.map((section) => (
        <div key={section.title} className="space-y-8">
          <h2 className="text-xs uppercase tracking-[0.18em] text-zinc-600">{section.title}</h2>
          <ul className="space-y-10">
            {section.items.map((link) => (
              <IntentionLinkRow key={link.id} link={link} periodSlug={periodSlug} />
            ))}
          </ul>
        </div>
      ))}
    </section>
  );
}

function KeyPieceRow({
  piece,
  periodSlug,
}: {
  piece: KeyPiece;
  periodSlug?: string;
}) {
  const item = toContinuationItem({
    id: piece.id,
    text: piece.text,
    entryId: piece.entryId,
    kind: "key_piece",
  });

  return (
    <li>
      <RoundupLineObservation
        itemId={piece.id}
        text={piece.text}
        signal="revisited"
        periodSlug={periodSlug}
      >
        <p className="text-[15px] font-normal leading-[1.75] text-zinc-300/95">{piece.text}</p>
        <RoundupContinuationActions item={item} periodSlug={periodSlug} />
        <ShareQuietlyButton card={buildQuietShareCard({
          id: `share-key-piece-${piece.id}`,
          line: piece.text,
          source: "roundup",
          sourceId: piece.id,
          entryId: piece.entryId,
        })} />
        <RoundupSourceLink
          item={item}
          entryId={piece.entryId}
          periodSlug={periodSlug}
          className="text-xs text-zinc-600/90 transition-colors hover:text-zinc-400"
        >
          Source entry
        </RoundupSourceLink>
      </RoundupLineObservation>
    </li>
  );
}

function KeyPiecesSection({
  report,
  periodSlug,
}: {
  report: KeyPiecesReport;
  periodSlug?: string;
}) {
  if (!report.hasData) return null;

  return (
    <section className="space-y-8 border-t border-white/[0.06] pt-14">
      <h2 className="text-xs uppercase tracking-[0.18em] text-zinc-600">Worth noticing</h2>
      <ul className="space-y-10">
        {report.items.map((piece) => (
          <KeyPieceRow key={piece.id} piece={piece} periodSlug={periodSlug} />
        ))}
      </ul>
    </section>
  );
}

function RoundupLineRow({
  line,
  periodSlug,
}: {
  line: ReflectiveRoundupLine;
  periodSlug?: string;
}) {
  const entryId = line.entryIds[0] ?? "";
  const item = toContinuationItem({
    id: line.id,
    text: line.text,
    entryId,
    kind: "line",
  });

  return (
    <article>
      <RoundupLineObservation
        itemId={line.id}
        text={line.text}
        signal={line.signal}
        periodSlug={periodSlug}
      >
        <p className="text-[15px] font-normal leading-[1.75] text-zinc-300/95">{line.text}</p>
        <RoundupContinuationActions item={item} periodSlug={periodSlug} />
        <ShareQuietlyButton card={buildRoundupQuietShareCard(line)} />
        {line.entryIds.length > 0 ? (
          <div className="flex flex-wrap gap-x-4 gap-y-1 text-xs text-zinc-600/90">
            {line.entryIds.map((linkedEntryId, index) => (
              <RoundupSourceLink
                key={`${line.id}-${linkedEntryId}`}
                item={item}
                entryId={linkedEntryId}
                periodSlug={periodSlug}
                className="transition-colors hover:text-zinc-400"
              >
                {line.entryIds.length === 1 ? "Related entry" : `Related entry ${index + 1}`}
              </RoundupSourceLink>
            ))}
          </div>
        ) : null}
      </RoundupLineObservation>
    </article>
  );
}

export function ReflectiveRoundupView({
  roundup,
  keyPieces,
  intentionLinks,
  periodSlug,
  territoryLabel,
}: {
  roundup: ReflectiveRoundup;
  keyPieces?: KeyPiecesReport | null;
  intentionLinks?: RoundupIntentionLinksReport | null;
  periodSlug?: string;
  territoryLabel?: string | null;
}) {
  const hasLines = roundup.hasData && roundup.lines.length > 0;
  const hasKeyPieces = keyPieces?.hasData ?? false;
  const hasIntentionLinks = intentionLinks?.hasData ?? false;

  if (!hasLines && !hasKeyPieces && !hasIntentionLinks) {
    return (
      <p className="text-sm leading-relaxed text-zinc-500">
        Nothing to gather from this period yet.
      </p>
    );
  }

  return (
    <div className="space-y-14">
      {territoryLabel ? (
        <p className="text-sm text-zinc-500">
          Key pieces filtered to {territoryLabel.toLowerCase()}.
        </p>
      ) : null}
      {hasLines ? (
        <div className="space-y-14">
          {roundup.lines.map((line) => (
            <RoundupLineRow key={line.id} line={line} periodSlug={periodSlug} />
          ))}
        </div>
      ) : null}

      {intentionLinks ? (
        <IntentionLinksSection report={intentionLinks} periodSlug={periodSlug} />
      ) : null}

      {keyPieces ? <KeyPiecesSection report={keyPieces} periodSlug={periodSlug} /> : null}
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
