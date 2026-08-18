"use client";

import { useEffect, useState } from "react";

import {
  buildArchiveOwnershipReport,
  buildSparseHomepageOwnershipLine,
} from "@/lib/archive/archive-ownership";
import { getAllEntries } from "@/lib/storage";

export function ArchiveOwnershipSparseLine() {
  const [line, setLine] = useState<string | null>(null);

  useEffect(() => {
    void buildArchiveOwnershipReport(getAllEntries()).then((report) => {
      setLine(buildSparseHomepageOwnershipLine(report));
    });
  }, []);

  if (!line) return null;

  return (
    <p className="text-sm font-normal leading-[1.75] text-zinc-500">{line}</p>
  );
}
