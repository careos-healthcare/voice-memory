"use client";

import { Download } from "lucide-react";

import { Button } from "@/archived-components/_archived/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/archived-components/_archived/ui/card";
import { downloadFounderAcquisitionJson } from "@/lib/debug/acquisition-review";
import type { AcquisitionReviewReport } from "@/types/acquisition-review";

function CheckRow({ label, ok }: { label: string; ok: boolean }) {
  return (
    <div className="flex items-center justify-between gap-3 text-sm">
      <span className="text-zinc-400">{label}</span>
      <span className={ok ? "text-emerald-300/90" : "text-zinc-600"}>{ok ? "Yes" : "Not yet"}</span>
    </div>
  );
}

function LineList({
  title,
  rows,
  empty,
}: {
  title: string;
  rows: Array<{ text: string; score?: number; ok?: boolean }>;
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
                key={row.text}
                className="rounded-lg border border-white/[0.06] px-3 py-2 text-sm text-zinc-300"
              >
                <p>{row.text}</p>
                {row.score !== undefined ? (
                  <p className="mt-1 text-[10px] uppercase tracking-wider text-zinc-600">
                    clarity {row.score}
                    {row.ok === false ? " · needs work" : ""}
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

export function AcquisitionReviewPanel({ report }: { report: AcquisitionReviewReport }) {
  const comprehension = report.comprehensionSummary;

  return (
    <div className="space-y-6">
      <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
        <Card>
          <CardHeader className="pb-1">
            <CardTitle className="text-xs font-normal uppercase tracking-wider text-zinc-500">
              Clarity score
            </CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-2xl font-semibold tabular-nums text-white">
              {report.averageEmotionalClarityScore}
            </p>
          </CardContent>
        </Card>
        <Card>
          <CardHeader className="pb-1">
            <CardTitle className="text-xs font-normal uppercase tracking-wider text-zinc-500">
              Keyword coverage
            </CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-2xl font-semibold tabular-nums text-white">
              {report.keywordCoveragePercent}%
            </p>
          </CardContent>
        </Card>
        <Card>
          <CardHeader className="pb-1">
            <CardTitle className="text-xs font-normal uppercase tracking-wider text-zinc-500">
              Banned hits
            </CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-2xl font-semibold tabular-nums text-white">
              {report.bannedAbstractHits.length}
            </p>
          </CardContent>
        </Card>
        <Card>
          <CardHeader className="pb-1">
            <CardTitle className="text-xs font-normal uppercase tracking-wider text-zinc-500">
              Confusion risks
            </CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-2xl font-semibold tabular-nums text-white">
              {report.confusionRisks.length}
            </p>
          </CardContent>
        </Card>
      </div>

      <Card>
        <CardHeader className="pb-2">
          <CardTitle className="text-sm font-normal text-zinc-200">Current acquisition copy</CardTitle>
        </CardHeader>
        <CardContent className="space-y-4 text-sm leading-relaxed text-zinc-400">
          <div>
            <p className="text-[10px] uppercase tracking-wider text-zinc-600">Short description</p>
            <p className="mt-1 text-zinc-200">{report.shortDescription}</p>
          </div>
          <div>
            <p className="text-[10px] uppercase tracking-wider text-zinc-600">App Store keywords</p>
            <p className="mt-1 font-mono text-xs text-zinc-300">{report.appStoreKeywords}</p>
          </div>
          <div>
            <p className="text-[10px] uppercase tracking-wider text-zinc-600">Full description</p>
            <p className="mt-1 whitespace-pre-wrap">{report.fullDescription}</p>
          </div>
        </CardContent>
      </Card>

      {report.bannedAbstractHits.length > 0 ? (
        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-normal text-amber-200/90">
              Banned abstract phrases
            </CardTitle>
          </CardHeader>
          <CardContent>
            <ul className="space-y-2 text-sm text-zinc-400">
              {report.bannedAbstractHits.map((hit) => (
                <li key={`${hit.where}-${hit.phrase}`}>
                  <span className="text-amber-300/90">{hit.phrase}</span> in {hit.where}
                </li>
              ))}
            </ul>
          </CardContent>
        </Card>
      ) : null}

      <Card>
        <CardHeader className="pb-2">
          <CardTitle className="text-sm font-normal text-zinc-200">Keyword coverage</CardTitle>
        </CardHeader>
        <CardContent>
          <ul className="grid gap-2 sm:grid-cols-2">
            {report.keywordCoverage.map((row) => (
              <li
                key={row.keyword}
                className="flex items-center justify-between rounded-lg border border-white/[0.06] px-3 py-2 text-xs"
              >
                <span className="text-zinc-400">{row.keyword}</span>
                <span className={row.covered ? "text-emerald-300/90" : "text-zinc-600"}>
                  {row.covered ? "covered" : "missing"}
                </span>
              </li>
            ))}
          </ul>
        </CardContent>
      </Card>

      <div className="space-y-4">
        <h2 className="text-xs uppercase tracking-[0.18em] text-zinc-600">Screenshot sequence preview</h2>
        <div className="grid gap-4 lg:grid-cols-2">
          {report.screenshotSets.map((set) => (
            <Card key={set.id}>
              <CardHeader className="pb-2">
                <CardTitle className="text-sm font-normal text-zinc-200">{set.label}</CardTitle>
              </CardHeader>
              <CardContent>
                <ol className="space-y-2">
                  {set.clarityRows.map((row, index) => (
                    <li
                      key={row.text}
                      className="flex items-start justify-between gap-3 rounded-lg border border-white/[0.06] px-3 py-2"
                    >
                      <div>
                        <p className="text-[10px] uppercase tracking-wider text-zinc-600">
                          Screen {index + 1}
                        </p>
                        <p className="text-sm text-zinc-200">{row.text}</p>
                      </div>
                      <span
                        className={
                          row.normalUserWouldUnderstand
                            ? "text-[10px] uppercase text-emerald-300/90"
                            : "text-[10px] uppercase text-amber-300/90"
                        }
                      >
                        {row.normalUserWouldUnderstand ? "clear" : "check"}
                      </span>
                    </li>
                  ))}
                </ol>
              </CardContent>
            </Card>
          ))}
        </div>
      </div>

      <div className="grid gap-4 lg:grid-cols-2">
        <LineList
          title="Onboarding hook preview"
          rows={report.onboardingHookChecks.map((row) => ({
            text: row.text,
            score: row.emotionalClarityScore,
            ok: row.normalUserWouldUnderstand,
          }))}
          empty="No onboarding hooks."
        />
        <LineList
          title="Would a normal user understand this?"
          rows={report.emotionalClarityIssues.slice(0, 8).map((issue) => ({
            text: issue,
            ok: false,
          }))}
          empty="All checked lines read clearly."
        />
      </div>

      <Card>
        <CardHeader className="pb-2">
          <CardTitle className="text-sm font-normal text-zinc-200">
            First-session comprehension
          </CardTitle>
        </CardHeader>
        <CardContent className="space-y-2">
          <CheckRow label="Understood revisit behavior" ok={Boolean(comprehension.revisitUnderstood)} />
          <CheckRow label="Opened old reflection" ok={Boolean(comprehension.oldReflectionOpened)} />
          <CheckRow label="Replayed old audio" ok={Boolean(comprehension.audioReplayed)} />
          <CheckRow
            label="Returned after first revisit"
            ok={Boolean(comprehension.returnedAfterRevisit)}
          />
          <CheckRow
            label="Confusion events"
            ok={comprehension.confusionCount === 0}
          />
        </CardContent>
      </Card>

      <div className="flex flex-wrap gap-3">
        <Button type="button" variant="secondary" size="sm" onClick={() => downloadFounderAcquisitionJson(report)}>
          <Download className="h-4 w-4" />
          Export founder acquisition review
        </Button>
      </div>
    </div>
  );
}
