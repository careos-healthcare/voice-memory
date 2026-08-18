import {
  INTERNAL_COMMAND_PILLARS,
  INTERNAL_LAUNCH_ROUTE,
  LAUNCH_DECISION,
} from "@/lib/internal/internal-archive-registry";

type InternalHubDecisionHeaderProps = {
  route: string;
  title: string;
  subheadline: string;
  eyebrow?: string;
};

export function InternalHubDecisionHeader({
  route,
  title,
  subheadline,
  eyebrow = "Founder hub",
}: InternalHubDecisionHeaderProps) {
  const pillar = INTERNAL_COMMAND_PILLARS.find((p) => p.route === route);
  const isLaunch = route === INTERNAL_LAUNCH_ROUTE;
  const decisionQuestion = isLaunch
    ? LAUNCH_DECISION.decisionQuestion
    : pillar?.decisionQuestion;
  const decisionAction = isLaunch ? LAUNCH_DECISION.decisionAction : pillar?.decisionAction;

  return (
    <header className="mt-2">
      <p className="text-xs uppercase tracking-[0.2em] text-violet-300/80">{eyebrow}</p>
      <h1 className="mt-2 text-3xl font-semibold tracking-tight text-white">{title}</h1>
      <p className="mt-2 max-w-2xl text-sm leading-relaxed text-zinc-400">{subheadline}</p>
      {decisionQuestion ? (
        <div className="mt-4 rounded-xl border border-white/10 bg-black/30 px-4 py-3">
          <p className="text-xs uppercase tracking-wide text-zinc-600">Decision</p>
          <p className="mt-1 text-sm font-medium text-zinc-200">{decisionQuestion}</p>
          {decisionAction ? (
            <p className="mt-2 text-sm text-zinc-500">{decisionAction}</p>
          ) : null}
        </div>
      ) : null}
    </header>
  );
}
