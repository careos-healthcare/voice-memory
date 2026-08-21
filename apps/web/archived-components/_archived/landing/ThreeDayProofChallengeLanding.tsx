import Link from "next/link";

import { LANDING_3_DAY_CHALLENGE } from "@/lib/product/landing-three-day-challenge-copy";

export function ThreeDayProofChallengeLanding() {
  const { steps, proSection, trust } = LANDING_3_DAY_CHALLENGE;

  return (
    <div
      className="mx-auto mt-10 max-w-md space-y-10 text-left"
      data-testid="landing-three-day-challenge"
    >
      <section aria-labelledby="landing-challenge-steps">
        <h2 id="landing-challenge-steps" className="sr-only">
          How it works
        </h2>
        <ol className="space-y-6">
          {steps.map((step, index) => (
            <li key={step.title} className="space-y-2">
              <p className="text-xs font-medium uppercase tracking-[0.16em] text-violet-300/80">
                Step {index + 1}
              </p>
              <h3 className="text-base font-medium text-zinc-100">{step.title}</h3>
              <p className="text-sm leading-relaxed text-zinc-400">{step.body}</p>
            </li>
          ))}
        </ol>
      </section>

      <section
        aria-labelledby="landing-chatgpt-differentiation"
        className="rounded-2xl border border-zinc-800/80 bg-zinc-900/40 p-5"
      >
        <p
          id="landing-chatgpt-differentiation"
          className="text-sm leading-relaxed text-zinc-300"
          data-testid="landing-chatgpt-differentiation"
        >
          {LANDING_3_DAY_CHALLENGE.chatGptDifferentiation}
        </p>
      </section>

      <section aria-labelledby="landing-pro-section" className="space-y-4">
        <h2 id="landing-pro-section" className="text-base font-medium text-zinc-100">
          {proSection.headline}
        </h2>
        <p
          className="text-sm leading-relaxed text-zinc-300"
          data-testid="landing-pro-paid-reason"
        >
          {proSection.paidReason}
        </p>
        <p className="text-sm leading-relaxed text-zinc-400">{proSection.freePositioning}</p>
        <ul className="space-y-2 text-sm leading-relaxed text-zinc-400">
          {proSection.bullets.map((bullet) => (
            <li key={bullet} className="flex gap-2">
              <span aria-hidden className="text-violet-300/70">
                ·
              </span>
              <span>{bullet}</span>
            </li>
          ))}
        </ul>
        <Link
          href="/pricing"
          className="inline-block text-sm text-violet-300 underline-offset-2 hover:text-violet-200 hover:underline"
        >
          See Pro →
        </Link>
      </section>

      <section
        aria-labelledby="landing-trust-section"
        className="space-y-3 border-t border-zinc-800/80 pt-8"
        data-testid="landing-trust-section"
      >
        <h2 id="landing-trust-section" className="text-sm font-medium text-zinc-200">
          {trust.headline}
        </h2>
        <ul className="space-y-2 text-sm leading-relaxed text-zinc-500">
          {trust.bullets.map((bullet) => (
            <li key={bullet}>{bullet}</li>
          ))}
        </ul>
      </section>
    </div>
  );
}
