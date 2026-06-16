import { FOUNDER_MODE_PREAMBLE } from "@/lib/internal/founder-focus-copy";

export function FounderModePreamble() {
  return (
    <section
      className="rounded-2xl border border-violet-500/25 bg-violet-950/30 px-4 py-4"
      data-testid="founder-mode-preamble"
    >
      <p className="text-sm font-medium text-violet-100">{FOUNDER_MODE_PREAMBLE.headline}</p>
      <p className="mt-2 text-sm text-zinc-400">{FOUNDER_MODE_PREAMBLE.body}</p>
      <ol className="mt-3 list-decimal space-y-1 pl-5 text-sm text-zinc-300">
        {FOUNDER_MODE_PREAMBLE.priorities.map((line) => (
          <li key={line}>{line}</li>
        ))}
      </ol>
    </section>
  );
}
