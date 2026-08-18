"use client";

import { useEffect } from "react";
import { useRouter, useSearchParams } from "next/navigation";

import { useClientHydrated } from "@/lib/hooks/use-client-hydrated";
import {
  markArchiveBeliefHomeRedirected,
  shouldAutoRedirectToArchiveBelief,
} from "@/lib/product/returning-home";

/** Once per session, send returning users to The Archive (all viewports). */
export function ReturningArchiveBeliefRedirect() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const hydrated = useClientHydrated();

  useEffect(() => {
    if (!hydrated) return;
    const stayOnHome = searchParams.get("stay") === "1";
    if (!shouldAutoRedirectToArchiveBelief({ stayOnHome, narrowMobile: false })) return;
    markArchiveBeliefHomeRedirected();
    router.replace("/archive-belief");
  }, [hydrated, router, searchParams]);

  return null;
}
