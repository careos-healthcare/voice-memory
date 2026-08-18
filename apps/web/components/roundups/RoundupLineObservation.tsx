"use client";

import type { ReactNode } from "react";
import { useEffect, useRef } from "react";

import {
  trackRoundupLineCopied,
  trackRoundupLinePausedOn,
} from "@/lib/roundups/roundup-observation";
import type { ReflectiveRoundupSignal } from "@/types/reflective-roundup";

const PAUSE_DWELL_MS = 1200;

export function RoundupLineObservation({
  itemId,
  text,
  signal,
  periodSlug,
  children,
}: {
  itemId: string;
  text: string;
  signal: ReflectiveRoundupSignal;
  periodSlug?: string;
  children: ReactNode;
}) {
  const rootRef = useRef<HTMLDivElement>(null);
  const pausedRef = useRef(false);
  const dwellStartRef = useRef<number | null>(null);

  useEffect(() => {
    const root = rootRef.current;
    if (!root) return;

    const onCopy = () => {
      const selection = window.getSelection()?.toString().trim() ?? "";
      if (!selection) return;
      if (!root.textContent?.includes(selection.slice(0, Math.min(24, selection.length)))) return;
      trackRoundupLineCopied({ itemId, text, signal, periodSlug });
    };

    root.addEventListener("copy", onCopy);
    return () => root.removeEventListener("copy", onCopy);
  }, [itemId, periodSlug, signal, text]);

  useEffect(() => {
    const root = rootRef.current;
    if (!root || typeof IntersectionObserver === "undefined") return;

    const observer = new IntersectionObserver(
      (entries) => {
        for (const entry of entries) {
          if (entry.isIntersecting && entry.intersectionRatio >= 0.6) {
            if (dwellStartRef.current === null) {
              dwellStartRef.current = Date.now();
            }
          } else if (dwellStartRef.current !== null) {
            const dwellMs = Date.now() - dwellStartRef.current;
            dwellStartRef.current = null;
            if (!pausedRef.current && dwellMs >= PAUSE_DWELL_MS) {
              pausedRef.current = true;
              trackRoundupLinePausedOn({ itemId, text, signal, periodSlug, dwellMs });
            }
          }
        }
      },
      { threshold: [0.6] },
    );

    observer.observe(root);
    return () => observer.disconnect();
  }, [itemId, periodSlug, signal, text]);

  return (
    <div ref={rootRef} className="space-y-3">
      {children}
    </div>
  );
}
