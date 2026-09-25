const milestones = [
  "Live cross-device sync",
  "Apple Voice Memos import",
  "Pattern exploration with direct verbatim voice citations",
];

export function Roadmap() {
  return (
    <section className="mt-12" aria-labelledby="roadmap-heading">
      <h2 id="roadmap-heading" className="text-lg font-medium text-white">
        Roadmap
      </h2>
      <p className="mt-2 text-sm leading-relaxed text-zinc-400">
        Coming to Android October 2026.
      </p>
      <ul className="mt-4 space-y-2 text-base leading-relaxed text-zinc-200">
        {milestones.map((item) => (
          <li key={item}>{item}</li>
        ))}
      </ul>
    </section>
  );
}
