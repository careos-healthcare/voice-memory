const liveFeatures = [
  "Pattern exploration with direct verbatim voice citations",
  "Apple Voice Memos import",
];

export function Roadmap() {
  return (
    <>
      <section className="mt-12" aria-labelledby="live-features-heading">
        <h2 id="live-features-heading" className="font-serif text-lg font-medium text-[#172033]">
          Active features
        </h2>
        <ul className="mt-4 space-y-2 text-base leading-relaxed text-[#3F4757]">
          {liveFeatures.map((item) => (
            <li key={item}>{item}</li>
          ))}
        </ul>
      </section>
      <section className="mt-12" aria-labelledby="roadmap-heading">
        <h2 id="roadmap-heading" className="font-serif text-lg font-medium text-[#172033]">
          Roadmap
        </h2>
        <p className="mt-2 text-sm leading-relaxed text-[#667085]">
          Coming to Android October 2026.
        </p>
      </section>
    </>
  );
}
