import type {
  BehaviorInsightLine,
  BehaviorTruthReport,
} from "@/types/behavior-truth";

function line(
  text: string,
  confidence: BehaviorInsightLine["confidence"],
  basedOn: string,
): BehaviorInsightLine {
  return { text, confidence, basedOn };
}

export function buildBehaviorInsightSummary(
  report: Pick<
    BehaviorTruthReport,
    | "funnels"
    | "surfaces"
    | "copyRows"
    | "ignoredSurfaces"
    | "strongestSurfaces"
    | "weakCopy"
    | "userSegments"
    | "productPressure"
  >,
): BehaviorInsightLine[] {
  const insights: BehaviorInsightLine[] = [];

  const callbackFunnel = report.funnels.find((f) => f.id === "callback_shown_to_opened");
  if (callbackFunnel && callbackFunnel.denominator >= 3) {
    if (callbackFunnel.percent < 20) {
      insights.push(
        line(
          "People often ignore callbacks unless the line feels personally anchored — abstract summaries may not earn the tap.",
          callbackFunnel.confidence,
          callbackFunnel.sampleNote,
        ),
      );
    } else if (callbackFunnel.percent >= 30) {
      insights.push(
        line(
          "Callbacks are being opened at a meaningful rate when shown on this device.",
          callbackFunnel.confidence,
          callbackFunnel.sampleNote,
        ),
      );
    }
  }

  const loopFunnel = report.funnels.find((f) => f.id === "open_loop_resurface_to_reflection");
  const homepage = report.surfaces.find((s) => s.id === "homepage_callback");
  const openLoopSurface = report.surfaces.find((s) => s.id === "open_loop_resurfacing");

  if (
    openLoopSurface &&
    homepage &&
    openLoopSurface.reflectionRate > homepage.reflectionRate + 10 &&
    openLoopSurface.seen >= 2
  ) {
    insights.push(
      line(
        "Open loops may create stronger return behavior than homepage callbacks on this device.",
        openLoopSurface.reflectionRate >= 25 ? "moderate" : "low",
        `open_loop reflection ${openLoopSurface.reflectionRate}% vs homepage ${homepage.reflectionRate}%`,
      ),
    );
  }

  const quoteStrong = report.copyRows.some(
    (row) =>
      row.verdict === "strong" &&
      /[“"']/.test(row.preview) &&
      !row.generic,
  );
  const genericWeak = report.weakCopy.some((row) => row.generic);
  if (quoteStrong) {
    insights.push(
      line(
        "Direct quotes may outperform abstract summaries when they appear in resurfacing lines.",
        "moderate",
        "copy effectiveness rows",
      ),
    );
  }
  if (genericWeak) {
    insights.push(
      line(
        "Some generic resurfacing lines are shown often but rarely lead to another reflection.",
        "moderate",
        "weak/generic copy audit",
      ),
    );
  }

  const atmosphere = report.surfaces.find((s) => s.id === "atmosphere");
  if (atmosphere && atmosphere.seen >= 2 && atmosphere.reflectionRate < 5) {
    insights.push(
      line(
        "Atmosphere images may be viewed or set without driving another reflection on this device.",
        atmosphere.seen >= 5 ? "moderate" : "low",
        `${atmosphere.seen} atmosphere events`,
      ),
    );
  }

  const oneAndDone = report.userSegments.find((s) => s.segment === "one_and_done");
  if (oneAndDone) {
    insights.push(
      line(
        "This device shows one-and-done risk — a second reflection exists but long gaps suggest the habit may not have formed.",
        "moderate",
        oneAndDone.signals.join(", "),
      ),
    );
  }

  const active = report.userSegments.find((s) => s.segment === "emotionally_active");
  if (active) {
    insights.push(
      line(
        "Returns cluster with shorter gaps — emotionally active use on this device.",
        "moderate",
        active.signals.join(", "),
      ),
    );
  }

  if (report.ignoredSurfaces.length > 0) {
    const names = report.ignoredSurfaces.map((s) => s.label).join(", ");
    insights.push(
      line(
        `These surfaces are often seen but ignored: ${names}.`,
        "moderate",
        "surface effectiveness",
      ),
    );
  }

  if (report.strongestSurfaces.length > 0) {
    const top = report.strongestSurfaces[0];
    if (top) {
      insights.push(
        line(
          `${top.label} is among the strongest return triggers on this device so far.`,
          top.seen >= 6 ? "moderate" : "low",
          top.plain,
        ),
      );
    }
  }

  const pressure = report.productPressure.find((w) => w.severity === "concern");
  if (pressure) {
    insights.push(line(pressure.plain, "moderate", "product pressure detector"));
  }

  if (insights.length === 0) {
    insights.push(
      line(
        "Not enough local behavior yet — record on a phone, revisit after a callback, then refresh.",
        "low",
        "event count",
      ),
    );
  }

  return insights.slice(0, 8);
}
