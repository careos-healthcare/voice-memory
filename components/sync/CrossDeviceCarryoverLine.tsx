"use client";

import { useEffect, useState } from "react";
import Link from "next/link";

import {
  buildHomepageCarryoverLine,
  type HomepageCarryover,
} from "@/lib/sync/cross-device-continuity";

export function CrossDeviceCarryoverLine() {
  const [carryover, setCarryover] = useState<HomepageCarryover | null>(null);

  useEffect(() => {
    const id = requestAnimationFrame(() => {
      setCarryover(buildHomepageCarryoverLine({ requirePending: true }));
    });
    return () => cancelAnimationFrame(id);
  }, []);

  if (!carryover) return null;

  const content = (
    <p className="text-sm font-normal leading-[1.75] text-zinc-400">{carryover.line}</p>
  );

  if (carryover.href) {
    return (
      <Link
        href={carryover.href}
        className="block rounded-xl border border-white/[0.06] bg-white/[0.02] px-4 py-3 transition-colors hover:bg-white/[0.04]"
      >
        {content}
      </Link>
    );
  }

  return (
    <div className="rounded-xl border border-white/[0.06] bg-white/[0.02] px-4 py-3">
      {content}
    </div>
  );
}
