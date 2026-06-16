"use client";

import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import type { BlindSpotDiscoveryReport } from "@/types/blind-spot-discovery";

interface BlindSpotDiscoveryPanelProps {
  report: BlindSpotDiscoveryReport;
}

export function BlindSpotDiscoveryPanel({ report }: BlindSpotDiscoveryPanelProps) {
  return (
    <div className="space-y-6">
      <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
        <Card className="border-white/10 bg-zinc-900/50">
          <CardHeader className="pb-2">
            <CardTitle className="text-sm text-zinc-400">Blind spot opens</CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-2xl font-semibold text-white">
              {report.surfaceOpens.blindSpotOpened}
            </p>
          </CardContent>
        </Card>
        <Card className="border-white/10 bg-zinc-900/50">
          <CardHeader className="pb-2">
            <CardTitle className="text-sm text-zinc-400">Emerging pattern opens</CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-2xl font-semibold text-white">
              {report.surfaceOpens.emergingPatternOpened}
            </p>
          </CardContent>
        </Card>
        <Card className="border-white/10 bg-zinc-900/50">
          <CardHeader className="pb-2">
            <CardTitle className="text-sm text-zinc-400">Prediction review opens</CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-2xl font-semibold text-white">
              {report.surfaceOpens.predictionReviewOpened}
            </p>
          </CardContent>
        </Card>
        <Card className="border-white/10 bg-zinc-900/50">
          <CardHeader className="pb-2">
            <CardTitle className="text-sm text-zinc-400">Accuracy summary opens</CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-2xl font-semibold text-white">
              {report.surfaceOpens.predictionAccuracyOpened}
            </p>
          </CardContent>
        </Card>
      </div>

      <Card className="border-violet-500/20 bg-violet-950/15">
        <CardHeader className="pb-2">
          <CardTitle className="text-base text-violet-100">Top wow moments</CardTitle>
        </CardHeader>
        <CardContent className="space-y-2">
          {report.topWowMoments.length === 0 ? (
            <p className="text-sm text-zinc-600">No reactions yet.</p>
          ) : (
            report.topWowMoments.map((row) => (
              <p key={row.reviewId} className="text-sm text-zinc-400">
                <span className="text-zinc-200">{row.headline}</span> — wow {row.wowMomentScore} ·{" "}
                {row.patternType} · {row.reactionCount} reactions
              </p>
            ))
          )}
        </CardContent>
      </Card>

      <div className="grid gap-4 lg:grid-cols-2">
        <Card className="border-white/10 bg-zinc-900/50">
          <CardHeader className="pb-2">
            <CardTitle className="text-base text-zinc-200">Prediction reviews vs blind spots</CardTitle>
            <p className="text-xs text-zinc-500">
              Surface opens — which areas users explore relative to full blind spot review
            </p>
          </CardHeader>
          <CardContent className="space-y-2 text-sm text-zinc-400">
            <p>Blind spot opens: {report.surfaceEngagement.blindSpotOpens}</p>
            <p>Blind spot reactions: {report.surfaceEngagement.blindSpotReactions}</p>
            <p>
              Prediction review opens: {report.surfaceEngagement.predictionReviewOpens} · accuracy
              summary: {report.surfaceEngagement.predictionAccuracyOpens}
            </p>
            <p>
              Ratio (prediction opens ÷ blind spot opens):{" "}
              {report.surfaceEngagement.predictionOpensVsBlindSpotOpens.toFixed(2)}
            </p>
          </CardContent>
        </Card>
        <Card className="border-white/10 bg-zinc-900/50">
          <CardHeader className="pb-2">
            <CardTitle className="text-base text-zinc-200">Emerging patterns vs blind spots</CardTitle>
            <p className="text-xs text-zinc-500">
              Early hypotheses surfaced before a full expensive-belief review
            </p>
          </CardHeader>
          <CardContent className="space-y-2 text-sm text-zinc-400">
            <p>Emerging pattern opens: {report.surfaceEngagement.emergingPatternOpens}</p>
            <p>Blind spot opens: {report.surfaceEngagement.blindSpotOpens}</p>
            <p>
              Ratio (emerging ÷ blind spot opens):{" "}
              {report.surfaceEngagement.emergingOpensVsBlindSpotOpens.toFixed(2)}
            </p>
            <p>
              Opens per reaction: {report.surfaceEngagement.opensPerReaction} — depth of return
              visits
            </p>
          </CardContent>
        </Card>
      </div>

      <div className="grid gap-4 lg:grid-cols-2">
        <Card className="border-white/10 bg-zinc-900/50">
          <CardHeader className="pb-2">
            <CardTitle className="text-base text-zinc-200">Highest recognition patterns</CardTitle>
          </CardHeader>
          <CardContent className="space-y-2 text-sm text-zinc-400">
            {report.highestRecognitionPatterns.map((row) => (
              <p key={row.patternType}>
                {row.patternType}: wow {row.wowMomentScore} · surprising {row.surprisingCount} ·
                uncomfortably accurate {row.uncomfortablyAccurateCount}
              </p>
            ))}
          </CardContent>
        </Card>
        <Card className="border-white/10 bg-zinc-900/50">
          <CardHeader className="pb-2">
            <CardTitle className="text-base text-zinc-200">Lowest recognition patterns</CardTitle>
          </CardHeader>
          <CardContent className="space-y-2 text-sm text-zinc-400">
            {report.lowestRecognitionPatterns.map((row) => (
              <p key={row.patternType}>
                {row.patternType}: wow {row.wowMomentScore} · obvious {row.obviousCount} · wrong{" "}
                {row.completelyWrongCount}
              </p>
            ))}
          </CardContent>
        </Card>
      </div>

      <Card className="border-white/10 bg-zinc-900/50">
        <CardHeader className="pb-2">
          <CardTitle className="text-base text-zinc-200">Evidence strength vs wow score</CardTitle>
        </CardHeader>
        <CardContent className="space-y-2 text-sm text-zinc-400">
          {report.evidenceStrengthVsWow.map((row) => (
            <p key={row.bucket}>
              {row.bucket}: avg wow {row.averageWowScore} · {row.totalReactions} reactions
            </p>
          ))}
        </CardContent>
      </Card>

      <Card className="border-white/10 bg-zinc-900/50">
        <CardHeader className="pb-2">
          <CardTitle className="text-base text-zinc-200">Reflection count vs wow score</CardTitle>
        </CardHeader>
        <CardContent className="space-y-2 text-sm text-zinc-400">
          {report.reflectionCountVsWow.map((row) => (
            <p key={row.bucket}>
              {row.bucket}: avg wow {row.averageWowScore} · {row.totalReactions} reactions
            </p>
          ))}
        </CardContent>
      </Card>

      <Card className="border-white/10 bg-zinc-900/50">
        <CardHeader className="pb-2">
          <CardTitle className="text-base text-zinc-200">Archive age vs wow score</CardTitle>
        </CardHeader>
        <CardContent className="space-y-2 text-sm text-zinc-400">
          {report.archiveAgeVsWow.map((row) => (
            <p key={row.bucket}>
              {row.bucket}: avg wow {row.averageWowScore} · {row.totalReactions} reactions
            </p>
          ))}
        </CardContent>
      </Card>

      <Card className="border-white/10 bg-zinc-900/50">
        <CardHeader className="pb-2">
          <CardTitle className="text-base text-zinc-200">Breakthrough phrases</CardTitle>
          <p className="text-xs text-zinc-500">What users said felt most true</p>
        </CardHeader>
        <CardContent className="space-y-2 text-sm text-zinc-400">
          {report.breakthroughPhrases.length === 0 ? (
            <p className="text-zinc-600">No breakthrough captures yet.</p>
          ) : (
            report.breakthroughPhrases.map((row) => (
              <p key={row.phrase}>
                “{row.phrase}” — {row.count}×
              </p>
            ))
          )}
        </CardContent>
      </Card>

      <Card className="border-white/10 bg-zinc-900/50">
        <CardHeader className="pb-2">
          <CardTitle className="text-base text-zinc-200">Delayed validation</CardTitle>
        </CardHeader>
        <CardContent className="text-sm text-zinc-400">
          <p>Pending: {report.delayedValidation.pending}</p>
          <p>Responded: {report.delayedValidation.responded}</p>
          <p>Changed mind: {report.delayedValidation.changedMind}</p>
          <p>Still wrong: {report.delayedValidation.stillWrong}</p>
          <p>Now accurate: {report.delayedValidation.nowAccurate}</p>
        </CardContent>
      </Card>
    </div>
  );
}
