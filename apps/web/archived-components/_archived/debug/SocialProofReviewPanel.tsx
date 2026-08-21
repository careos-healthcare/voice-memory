"use client";

import { Download } from "lucide-react";

import { Button } from "@/archived-components/_archived/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/archived-components/_archived/ui/card";
import { downloadSocialProofReviewJson } from "@/lib/debug/social-proof-review";
import type { SocialProofReviewReport } from "@/types/social-proof";

function LineList({
  title,
  rows,
  empty,
}: {
  title: string;
  rows: Array<{ id: string; text: string; detail?: string; score?: number }>;
  empty: string;
}) {
  return (
    <Card>
      <CardHeader className="pb-2">
        <CardTitle className="text-sm font-normal text-zinc-200">{title}</CardTitle>
      </CardHeader>
      <CardContent>
        {rows.length === 0 ? (
          <p className="text-sm text-zinc-500">{empty}</p>
        ) : (
          <ul className="space-y-2">
            {rows.map((row) => (
              <li
                key={row.id}
                className="rounded-lg border border-white/[0.06] px-3 py-2 text-sm text-zinc-300"
              >
                <p>{row.text}</p>
                {row.detail ? (
                  <p className="mt-1 text-xs text-zinc-600">{row.detail}</p>
                ) : null}
                {row.score !== undefined ? (
                  <p className="mt-1 text-[10px] uppercase tracking-wider text-zinc-600">
                    residue {row.score}
                  </p>
                ) : null}
              </li>
            ))}
          </ul>
        )}
      </CardContent>
    </Card>
  );
}

export function SocialProofReviewPanel({ report }: { report: SocialProofReviewReport }) {
  return (
    <div className="space-y-6">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <p className="text-sm text-zinc-500">
          Quiet proof from real behavior and approved feedback — no fake numbers or urgency.
        </p>
        <Button type="button" variant="secondary" size="sm" onClick={() => downloadSocialProofReviewJson(report)}>
          <Download className="h-4 w-4" />
          Export social-proof-review.json
        </Button>
      </div>

      <div className="grid gap-4 lg:grid-cols-2">
        <LineList
          title="Approved testimonial candidates"
          rows={report.approvedTestimonialCandidates.map((row) => ({
            id: row.id,
            text: row.text,
            detail: `${row.status} · ${row.emotionalCategory}${row.reason ? ` · ${row.reason}` : ""}`,
          }))}
          empty="No approved or pending testimonials yet."
        />
        <LineList
          title="Rejected generic testimonials"
          rows={report.rejectedGenericTestimonials.map((row) => ({
            id: row.id,
            text: row.text,
            detail: row.reason,
          }))}
          empty="No rejected testimonials."
        />
        <LineList
          title="Revisit stories"
          rows={report.revisitStories}
          empty="No revisit stories recorded."
        />
        <LineList
          title="Strongest emotional residue callbacks"
          rows={report.strongestResidueCallbacks}
          empty="No callbacks with residue yet."
        />
        <LineList
          title="Revisit → reflection stories"
          rows={report.revisitReflectionStories.map((row) => ({
            id: row.entryId,
            text: `Entry ${row.entryId.slice(0, 8)}`,
            detail: row.detail,
          }))}
          empty="No revisit → reflection links yet."
        />
        <LineList
          title="Copied moments"
          rows={report.copiedMoments}
          empty="No copied moments yet."
        />
        <LineList
          title="Remembered-72h callbacks"
          rows={report.remembered72hCallbacks}
          empty="No 72h remembrance flags yet."
        />
        <LineList
          title="Overclaimed emotional lines"
          rows={report.overclaimedEmotionalLines}
          empty="No overclaimed lines detected."
        />
      </div>

      <Card>
        <CardHeader className="pb-2">
          <CardTitle className="text-sm font-normal text-zinc-200">Quiet proof snippets</CardTitle>
        </CardHeader>
        <CardContent>
          <ul className="space-y-2">
            {report.quietProofSnippets.map((row) => (
              <li
                key={row.id}
                className="rounded-lg bg-white/[0.03] px-3 py-2 text-sm text-zinc-300"
              >
                <p>{row.text}</p>
                <p className="mt-1 text-[10px] uppercase tracking-wider text-zinc-600">
                  {row.source} · strength {row.strength}
                  {row.evidence ? ` · ${row.evidence}` : ""}
                </p>
              </li>
            ))}
          </ul>
        </CardContent>
      </Card>
    </div>
  );
}
