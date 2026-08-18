"use client";

import { useEffect } from "react";
import { usePathname } from "next/navigation";

import { completePushVerificationOpenPending } from "@/lib/notifications/push-verification";

/** Finishes push verification when user lands on target after notification tap. */
export function PushVerificationBootstrap() {
  const pathname = usePathname();

  useEffect(() => {
    if (!pathname) return;
    completePushVerificationOpenPending(pathname);
  }, [pathname]);

  return null;
}
