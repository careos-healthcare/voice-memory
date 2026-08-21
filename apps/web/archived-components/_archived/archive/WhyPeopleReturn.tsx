"use client";

import {
  WHY_PEOPLE_RETURN_HEADING,
  WHY_PEOPLE_RETURN_LINES,
} from "@/lib/archive/why-people-return-copy";
import { cn } from "@/lib/utils";

type WhyPeopleReturnProps = {
  className?: string;
};

export function WhyPeopleReturn({ className = "" }: WhyPeopleReturnProps) {
  return (
    <section
      className={cn("rounded-2xl border border-white/10 bg-zinc-900/40 px-4 py-4", className)}
      data-testid="why-people-return"
    >
      <p className="text-sm font-medium text-zinc-200">{WHY_PEOPLE_RETURN_HEADING}</p>
      <ul className="mt-3 space-y-1.5 text-sm text-zinc-400">
        {WHY_PEOPLE_RETURN_LINES.map((line) => (
          <li key={line}>{line}</li>
        ))}
      </ul>
    </section>
  );
}
