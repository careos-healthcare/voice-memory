"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { CheckCircle2, Circle, Rocket } from "lucide-react";

import { SiteHeader } from "@/components/SiteHeader";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import {
  getLaunchChecklistProgress,
  getLaunchChecklistState,
  LAUNCH_CHECKLIST,
  resetLaunchChecklist,
  setLaunchChecklistItem,
} from "@/lib/launch-checklist";

export default function LaunchPage() {
  const [checked, setChecked] = useState<Record<string, boolean>>({});
  const [progress, setProgress] = useState({ checked: 0, total: 0, percent: 0 });

  const refresh = () => {
    setChecked(getLaunchChecklistState());
    setProgress(getLaunchChecklistProgress());
  };

  useEffect(() => {
    refresh();
  }, []);

  const toggle = (id: string) => {
    const next = !checked[id];
    setLaunchChecklistItem(id, next);
    refresh();
  };

  const categories = [...new Set(LAUNCH_CHECKLIST.map((item) => item.category))];

  return (
    <div className="min-h-screen bg-zinc-950">
      <div className="mx-auto max-w-3xl px-4 pb-20 sm:px-6">
        <SiteHeader />

        <header className="mt-2">
          <p className="text-xs uppercase tracking-[0.2em] text-violet-300/80">Launch preparation</p>
          <h1 className="mt-2 text-3xl font-semibold tracking-tight text-white">
            Launch checklist
          </h1>
          <p className="mt-2 text-sm text-zinc-400">
            Production readiness review — check items off locally as you validate.
          </p>
        </header>

        <Card className="mt-6 border-violet-400/20 bg-violet-500/5">
          <CardContent className="flex items-center gap-4 py-5">
            <div className="flex h-12 w-12 items-center justify-center rounded-full bg-violet-500/20">
              <Rocket className="h-6 w-6 text-violet-300" />
            </div>
            <div className="flex-1">
              <p className="text-sm font-medium text-white">
                {progress.checked} of {progress.total} complete
              </p>
              <div className="mt-2 h-2 overflow-hidden rounded-full bg-white/10">
                <div
                  className="h-full rounded-full bg-gradient-to-r from-violet-500 to-fuchsia-400 transition-all"
                  style={{ width: `${progress.percent}%` }}
                />
              </div>
            </div>
            <p className="text-2xl font-semibold tabular-nums text-violet-200">
              {progress.percent}%
            </p>
          </CardContent>
        </Card>

        <div className="mt-6 space-y-8">
          {categories.map((category) => (
            <section key={category}>
              <h2 className="text-sm font-medium uppercase tracking-wider text-zinc-500">
                {category}
              </h2>
              <ul className="mt-3 space-y-2">
                {LAUNCH_CHECKLIST.filter((item) => item.category === category).map((item) => {
                  const isChecked = Boolean(checked[item.id]);
                  return (
                    <li key={item.id}>
                      <button
                        type="button"
                        onClick={() => toggle(item.id)}
                        className={`flex w-full items-start gap-3 rounded-2xl border px-4 py-3 text-left transition-colors ${
                          isChecked
                            ? "border-emerald-500/30 bg-emerald-500/5"
                            : "border-white/10 bg-white/[0.02] hover:bg-white/[0.04]"
                        }`}
                      >
                        {isChecked ? (
                          <CheckCircle2 className="mt-0.5 h-5 w-5 shrink-0 text-emerald-400" />
                        ) : (
                          <Circle className="mt-0.5 h-5 w-5 shrink-0 text-zinc-600" />
                        )}
                        <span>
                          <span className="block text-sm font-medium text-white">{item.label}</span>
                          <span className="mt-1 block text-xs leading-relaxed text-zinc-500">
                            {item.description}
                          </span>
                        </span>
                      </button>
                    </li>
                  );
                })}
              </ul>
            </section>
          ))}
        </div>

        <div className="mt-8 flex flex-wrap gap-3">
          <Button type="button" variant="ghost" size="sm" onClick={() => { resetLaunchChecklist(); refresh(); }}>
            Reset checklist
          </Button>
          <Link href="/debug/retention" className="text-sm text-violet-300 hover:text-violet-200 self-center">
            Retention dashboard →
          </Link>
          <Link href="/demo" className="text-sm text-zinc-500 hover:text-zinc-300 self-center">
            Demo mode →
          </Link>
        </div>
      </div>
    </div>
  );
}
