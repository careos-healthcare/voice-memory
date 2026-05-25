"use client";

import Link from "next/link";
import { motion } from "framer-motion";
import { Sparkles } from "lucide-react";

import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { WEDGE_RESURFACING } from "@/lib/product-copy";
import type { ConservativePattern } from "@/lib/insights/conservative-patterns";

interface PatternsDetectedSectionProps {
  patterns: ConservativePattern[];
  disclaimer: string;
}

export function PatternsDetectedSection({
  patterns,
  disclaimer,
}: PatternsDetectedSectionProps) {
  if (patterns.length === 0) {
    return (
      <Card className="border-dashed border-white/5">
        <CardHeader className="pb-2">
          <CardTitle className="text-base font-medium text-zinc-400">
            Repeated words in your archive
          </CardTitle>
        </CardHeader>
        <CardContent>
          <p className="text-sm text-zinc-500">
            {WEDGE_RESURFACING.forgottenPatterns} Not therapy or a diagnosis.
          </p>
        </CardContent>
      </Card>
    );
  }

  return (
    <Card className="border-white/5">
      <CardHeader className="pb-2">
        <div className="flex items-center gap-2">
          <Sparkles className="h-4 w-4 text-violet-300/80" />
          <CardTitle className="text-base font-medium text-zinc-200">
            Repeated words in your archive
          </CardTitle>
        </div>
        <p className="mt-1 text-xs leading-relaxed text-zinc-600">{disclaimer}</p>
      </CardHeader>
      <CardContent className="space-y-4">
        {patterns.map((pattern, index) => (
          <motion.div
            key={pattern.id}
            initial={{ opacity: 0, y: 8 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: index * 0.04 }}
            className="rounded-xl border border-white/5 bg-black/10 p-4"
          >
            <p className="text-[10px] font-medium uppercase tracking-wider text-violet-300/80">
              {pattern.label}
            </p>
            <p className="mt-2 text-sm leading-relaxed text-zinc-300">
              {pattern.observation}
            </p>
            <p className="mt-2 text-xs leading-relaxed text-zinc-500">
              {pattern.detail}
            </p>
            {pattern.entryIds.length > 0 ? (
              <div className="mt-3 flex flex-wrap gap-2">
                {pattern.entryIds.slice(0, 3).map((entryId) => (
                  <Link
                    key={entryId}
                    href={`/entry/${entryId}`}
                    className="text-xs text-zinc-500 underline-offset-2 hover:text-violet-300 hover:underline"
                  >
                    View entry
                  </Link>
                ))}
              </div>
            ) : null}
          </motion.div>
        ))}
      </CardContent>
    </Card>
  );
}
