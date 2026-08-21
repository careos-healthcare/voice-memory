import { Card, CardContent, CardHeader, CardTitle } from "@/archived-components/_archived/ui/card";
import { WHY_THIS_MATTERS_TOPICS, type WhyThisMattersTopic } from "@/lib/why-this-matters";

interface WhyThisMattersProps {
  topics?: WhyThisMattersTopic[];
  compact?: boolean;
  className?: string;
}

export function WhyThisMatters({
  topics = WHY_THIS_MATTERS_TOPICS,
  compact = false,
  className,
}: WhyThisMattersProps) {
  if (compact) {
    return (
      <div className={`grid gap-3 sm:grid-cols-2 ${className ?? ""}`}>
        {topics.map((topic) => (
          <div
            key={topic.id}
            className="rounded-2xl border border-white/10 bg-white/[0.02] px-4 py-3"
          >
            <p className="text-sm font-medium text-white">{topic.title}</p>
            <p className="mt-1 text-xs leading-relaxed text-zinc-500">{topic.summary}</p>
          </div>
        ))}
      </div>
    );
  }

  return (
    <div className={`space-y-4 ${className ?? ""}`}>
      <div>
        <p className="text-xs uppercase tracking-[0.2em] text-violet-300/80">Why this matters</p>
        <h2 className="mt-2 text-xl font-semibold text-white">
          Remembering over time
        </h2>
        <p className="mt-2 text-sm text-zinc-400">
          ArchiveMe holds your words — not labels from a clinician.
        </p>
      </div>
      {topics.map((topic) => (
        <Card key={topic.id}>
          <CardHeader className="pb-2">
            <CardTitle className="text-base">{topic.title}</CardTitle>
            <p className="text-xs text-zinc-500">{topic.summary}</p>
          </CardHeader>
          <CardContent>
            <p className="text-sm leading-relaxed text-zinc-400">{topic.detail}</p>
          </CardContent>
        </Card>
      ))}
    </div>
  );
}
