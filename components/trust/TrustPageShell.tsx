import type { ReactNode } from "react";

import { SiteFooter } from "@/components/SiteFooter";
import { SiteHeader } from "@/components/SiteHeader";

export function TrustPageShell({
  eyebrow,
  title,
  description,
  children,
}: {
  eyebrow: string;
  title: string;
  description?: string;
  children: ReactNode;
}) {
  return (
    <div className="min-h-screen bg-zinc-950">
      <div className="mx-auto max-w-3xl px-4 pb-20 sm:px-6">
        <SiteHeader />
        <header className="mt-2">
          <p className="text-xs uppercase tracking-[0.2em] text-violet-300/80">{eyebrow}</p>
          <h1 className="mt-2 text-3xl font-semibold tracking-tight text-white">{title}</h1>
          {description ? (
            <p className="mt-3 text-sm leading-relaxed text-zinc-400">{description}</p>
          ) : null}
        </header>
        <div className="mt-8 space-y-6">{children}</div>
        <SiteFooter className="mt-12" />
      </div>
    </div>
  );
}

export function TrustSection({
  title,
  body,
}: {
  title: string;
  body: string;
}) {
  return (
    <section className="rounded-2xl border border-white/10 bg-white/[0.02] p-5">
      <h2 className="text-base font-semibold text-white">{title}</h2>
      <p className="mt-2 text-sm leading-relaxed text-zinc-400">{body}</p>
    </section>
  );
}
