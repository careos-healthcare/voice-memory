"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { Heart } from "lucide-react";

import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import {
  buildArchiveOwnershipReport,
  buildArchivePageOwnershipLines,
  buildOldestEntryLink,
} from "@/lib/archive/archive-ownership";
import { getAllEntries } from "@/lib/storage";
import type { ArchiveOwnershipReport } from "@/types/archive-ownership";

export function ArchiveOwnershipPanel() {
  const [report, setReport] = useState<ArchiveOwnershipReport | null>(null);

  useEffect(() => {
    void buildArchiveOwnershipReport(getAllEntries()).then(setReport);
  }, []);

  if (!report) return null;

  const lines = buildArchivePageOwnershipLines(report);
  const oldestLink = buildOldestEntryLink(report);

  return (
    <Card className="border-white/[0.06] bg-zinc-900/40">
      <CardHeader>
        <CardTitle className="flex items-center gap-2 text-base font-normal text-zinc-200">
          <Heart className="h-4 w-4 text-violet-300/80" />
          Your archive
        </CardTitle>
      </CardHeader>
      <CardContent className="space-y-3 text-sm leading-[1.75] text-zinc-500">
        {lines.primary ? <p>{lines.primary}</p> : null}
        {lines.secondary ? <p>{lines.secondary}</p> : null}
        {lines.reassurance ? <p className="text-zinc-600">{lines.reassurance}</p> : null}
        {oldestLink ? (
          <Button asChild variant="ghost" size="sm" className="mt-1 px-0 text-violet-300 hover:text-violet-200">
            <Link href={oldestLink.href}>{oldestLink.label} →</Link>
          </Button>
        ) : null}
      </CardContent>
    </Card>
  );
}
