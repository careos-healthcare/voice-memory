import { PRIVACY_TRUST_POINTS, PRIVATE_BY_DEFAULT_LINE } from "@/lib/trust-copy";

export function PrivacyTrustPanel({ compact = false }: { compact?: boolean }) {
  return (
    <div className={compact ? "space-y-3" : "space-y-4"}>
      <p className="text-sm leading-relaxed text-zinc-400">{PRIVATE_BY_DEFAULT_LINE}</p>
      <ul className="space-y-3">
        {PRIVACY_TRUST_POINTS.map((point) => (
          <li key={point.title}>
            <p className="text-sm font-medium text-zinc-300">{point.title}</p>
            <p className="mt-1 text-sm leading-relaxed text-zinc-500">{point.body}</p>
          </li>
        ))}
      </ul>
    </div>
  );
}
