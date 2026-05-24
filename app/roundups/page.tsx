"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { motion } from "framer-motion";

import { ReflectiveRoundupIndex } from "@/components/roundups/ReflectiveRoundupView";
import { SiteHeader } from "@/components/SiteHeader";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { listReflectiveRoundups } from "@/lib/roundups/reflective-roundups";
import type { RoundupListReport } from "@/types/reflective-roundup";

export default function RoundupsPage() {
  const [report, setReport] = useState<RoundupListReport | null>(null);

  useEffect(() => {
    const id = requestAnimationFrame(() => {
      setReport(listReflectiveRoundups());
    });
    return () => cancelAnimationFrame(id);
  }, []);

  const loading = report === null;

  return (
    <div className="min-h-screen bg-zinc-950">
      <div className="mx-auto max-w-3xl px-4 pb-24 sm:px-6">
        <SiteHeader />

        <motion.header initial={{ opacity: 0, y: 12 }} animate={{ opacity: 1, y: 0 }} className="mt-2">
          <p className="text-xs uppercase tracking-[0.2em] text-zinc-600">Roundups</p>
          <h1 className="mt-3 text-3xl font-semibold tracking-tight text-white">Remembered continuity</h1>
          <p className="mt-3 max-w-xl text-sm leading-relaxed text-zinc-500">
            A few lines from what kept returning, what faded, and what changed — not a report.
          </p>
        </motion.header>

        <div className="mt-16">
          {loading ? (
            <Card>
              <CardContent className="py-16 text-center text-sm text-zinc-600">
                Reading your archive…
              </CardContent>
            </Card>
          ) : (
            <ReflectiveRoundupIndex items={report.items} />
          )}
        </div>

        <div className="mt-16 flex flex-wrap gap-4 text-sm">
          <Link href="/roundups" className="text-zinc-500 transition-colors hover:text-zinc-300">
            Roundups →
          </Link>
          <Link href="/memory" className="text-zinc-500 transition-colors hover:text-zinc-300">
            Memory →
          </Link>
        </div>

        {!loading && report.items.length === 0 ? (
          <div className="mt-10">
            <Button asChild variant="secondary">
              <Link href="/">Record a reflection</Link>
            </Button>
          </div>
        ) : null}
      </div>
    </div>
  );
}
