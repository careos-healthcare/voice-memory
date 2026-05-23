"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { FlaskConical, LogOut, Play, Search } from "lucide-react";

import { SiteHeader } from "@/components/SiteHeader";
import { WhyThisMatters } from "@/components/WhyThisMatters";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import {
  DEMO_SEARCH_EXAMPLES,
  enterDemoMode,
  exitDemoMode,
  getDemoEntryCount,
  isDemoModeActive,
} from "@/lib/demo-mode";

export default function DemoPage() {
  const router = useRouter();
  const [active, setActive] = useState(false);
  const [message, setMessage] = useState<string | null>(null);

  useEffect(() => {
    setActive(isDemoModeActive());
  }, []);

  const showMessage = (text: string) => {
    setMessage(text);
    window.setTimeout(() => setMessage(null), 4000);
  };

  const handleEnter = () => {
    enterDemoMode();
    setActive(true);
    showMessage("Demo data loaded — your previous data is backed up locally.");
  };

  const handleExit = () => {
    const restored = exitDemoMode();
    setActive(false);
    showMessage(
      restored
        ? "Demo exited — your previous data was restored."
        : "Demo exited — no backup found, local data cleared.",
    );
  };

  return (
    <div className="min-h-screen bg-zinc-950">
      <div className="mx-auto max-w-3xl px-4 pb-20 sm:px-6">
        <SiteHeader />

        <header className="mt-2">
          <p className="text-xs uppercase tracking-[0.2em] text-violet-300/80">First-user testing</p>
          <h1 className="mt-2 text-3xl font-semibold tracking-tight text-white">Demo mode</h1>
          <p className="mt-2 text-sm leading-relaxed text-zinc-400">
            Explore VoiceMemory with realistic sample reflections — entities, weekly
            intelligence, memory continuity, and search examples. Your real data is backed
            up before entering and restored when you exit.
          </p>
        </header>

        {message ? (
          <p className="mt-4 rounded-xl border border-emerald-500/20 bg-emerald-500/10 px-4 py-3 text-sm text-emerald-200">
            {message}
          </p>
        ) : null}

        <Card className={`mt-6 ${active ? "border-amber-500/30 bg-amber-950/20" : ""}`}>
          <CardHeader className="pb-2">
            <div className="flex items-center gap-2">
              <FlaskConical className="h-4 w-4 text-violet-300" />
              <CardTitle className="text-base">
                {active ? "Demo mode active" : "Enter demo mode"}
              </CardTitle>
            </div>
          </CardHeader>
          <CardContent className="space-y-4">
            <p className="text-sm text-zinc-400">
              Loads {getDemoEntryCount()} seeded reflections spanning ~3 weeks — names
              (Sarah, Alex, Mum, Dad), money and family pressure themes, weekly summary
              cache, and entity memory.
            </p>
            <div className="flex flex-wrap gap-2">
              {!active ? (
                <Button type="button" onClick={handleEnter}>
                  <Play className="h-4 w-4" />
                  Enter demo mode
                </Button>
              ) : (
                <>
                  <Button type="button" variant="secondary" onClick={handleExit}>
                    <LogOut className="h-4 w-4" />
                    Exit demo mode
                  </Button>
                  <Button type="button" variant="ghost" onClick={() => router.push("/weekly")}>
                    View weekly intelligence
                  </Button>
                  <Button type="button" variant="ghost" onClick={() => router.push("/memory")}>
                    View entity memory
                  </Button>
                  <Button type="button" variant="ghost" onClick={() => router.push("/search")}>
                    Try semantic search
                  </Button>
                </>
              )}
            </div>
          </CardContent>
        </Card>

        <Card className="mt-4">
          <CardHeader className="pb-2">
            <div className="flex items-center gap-2">
              <Search className="h-4 w-4 text-fuchsia-300" />
              <CardTitle className="text-base">Semantic search examples</CardTitle>
            </div>
          </CardHeader>
          <CardContent>
            <p className="text-sm text-zinc-400">
              After entering demo, try these on{" "}
              <Link href="/search" className="text-violet-300 hover:text-violet-200">
                Search
              </Link>
              :
            </p>
            <ul className="mt-3 space-y-2">
              {DEMO_SEARCH_EXAMPLES.map((query) => (
                <li key={query} className="rounded-xl bg-white/[0.03] px-3 py-2 text-sm text-zinc-300">
                  &ldquo;{query}&rdquo;
                </li>
              ))}
            </ul>
          </CardContent>
        </Card>

        <div className="mt-8">
          <WhyThisMatters compact />
        </div>
      </div>
    </div>
  );
}
