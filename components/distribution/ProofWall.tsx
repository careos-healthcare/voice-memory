"use client";

import { useMemo } from "react";

import { buildProofWall } from "@/lib/distribution/proof-wall";
import { useClientHydrated } from "@/lib/hooks/use-client-hydrated";

type ProofWallProps = {
  className?: string;
};

/** Landing proof — real testimonials, archive moments, and tester quotes only. */
export function ProofWall({ className = "" }: ProofWallProps) {
  const hydrated = useClientHydrated();
  const wall = useMemo(() => (hydrated ? buildProofWall() : null), [hydrated]);

  if (!wall || wall.items.length === 0) return null;

  return (
    <section
      className={`rounded-2xl border border-white/10 bg-zinc-900/30 px-4 py-4 ${className}`}
      data-testid="proof-wall"
      data-has-real-proof={wall.hasRealProof ? "true" : "false"}
    >
      <p className="text-xs uppercase tracking-wide text-zinc-500">{wall.label}</p>
      <ul className="mt-3 space-y-3">
        {wall.items.map((item) => (
          <li key={item.id} data-proof-kind={item.kind}>
            {item.label ? (
              <p className="text-[10px] uppercase tracking-wider text-zinc-600">{item.label}</p>
            ) : null}
            <p className="text-sm italic leading-relaxed text-zinc-400">&ldquo;{item.text}&rdquo;</p>
          </li>
        ))}
      </ul>
    </section>
  );
}
