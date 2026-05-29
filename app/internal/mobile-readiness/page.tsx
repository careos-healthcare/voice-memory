"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { RefreshCw } from "lucide-react";

import { SiteHeader } from "@/components/SiteHeader";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import {
  buildMobileReadinessReport,
  type MobileReadinessCheck,
  type MobileReadinessReport,
} from "@/lib/mobile/mobile-readiness";
import { getNotificationSchedulerStatus } from "@/lib/notifications/scheduler";
import {
  isNativeWrapper,
  isPWA,
  supportsBackgroundAudio,
  supportsPush,
} from "@/lib/mobile/platform";

function statusColor(status: MobileReadinessCheck["status"]): string {
  if (status === "ready") return "text-emerald-400/90";
  if (status === "partial") return "text-amber-300/90";
  if (status === "blocked") return "text-red-300/90";
  return "text-zinc-500";
}

export default function MobileReadinessDebugPage() {
  const [report, setReport] = useState<MobileReadinessReport | null>(null);
  const push = getNotificationSchedulerStatus();

  const refresh = () => {
    void buildMobileReadinessReport().then(setReport);
  };

  useEffect(() => {
    refresh();
  }, []);

  return (
    <div className="min-h-screen-mobile bg-zinc-950 pb-safe">
      <div className="mx-auto max-w-3xl px-4 pb-20 sm:px-6">
        <SiteHeader />

        <header className="mt-2 flex items-start justify-between gap-4">
          <div>
            <p className="text-xs uppercase tracking-[0.2em] text-violet-300/80">Debug only</p>
            <h1 className="mt-2 text-3xl font-semibold tracking-tight text-white">
              Mobile readiness
            </h1>
            <p className="mt-2 max-w-2xl text-sm leading-relaxed text-zinc-400">
              PWA install path, storage pressure, microphone, push placeholders, and runtime
              boundaries for wrapper distribution.
            </p>
          </div>
          <Button type="button" variant="ghost" size="sm" onClick={refresh}>
            <RefreshCw className="h-4 w-4" />
            Refresh
          </Button>
        </header>

        <Card className="mt-6 border-white/10 bg-zinc-900/50">
          <CardHeader className="pb-2">
            <CardTitle className="text-base text-zinc-200">Platform</CardTitle>
          </CardHeader>
          <CardContent className="space-y-1 text-sm text-zinc-400">
            <p>Native wrapper: {isNativeWrapper() ? "yes" : "no"}</p>
            <p>PWA standalone: {isPWA() ? "yes" : "no"}</p>
            <p>Push capable: {supportsPush() ? "yes" : "no"}</p>
            <p>Background audio: {supportsBackgroundAudio() ? "partial" : "limited"}</p>
            <p className="text-xs text-zinc-600">
              Notifications: {push.mode} · {push.queuedCount} queued · {push.registeredTriggers}{" "}
              triggers
            </p>
          </CardContent>
        </Card>

        {report ? (
          <>
            <Card className="mt-4 border-white/10 bg-zinc-900/50">
              <CardHeader className="pb-2">
                <CardTitle className="text-base text-zinc-200">Checks</CardTitle>
              </CardHeader>
              <CardContent className="space-y-3">
                {report.checks.map((check) => (
                  <div key={check.id} className="border-b border-white/5 pb-3 last:border-0">
                    <p className={`text-sm font-medium ${statusColor(check.status)}`}>
                      {check.label} — {check.status}
                    </p>
                    <p className="mt-1 text-xs leading-relaxed text-zinc-500">{check.detail}</p>
                  </div>
                ))}
              </CardContent>
            </Card>

            {report.warnings.length > 0 ? (
              <Card className="mt-4 border-amber-500/20 bg-amber-950/20">
                <CardContent className="space-y-1 py-4 text-sm text-amber-100/90">
                  {report.warnings.map((warning) => (
                    <p key={warning}>{warning}</p>
                  ))}
                </CardContent>
              </Card>
            ) : null}

            <p className="mt-4 text-xs text-zinc-600">
              Runtime: {report.runtime} · {report.generatedAt}
            </p>
          </>
        ) : null}

        <div className="mt-8 flex flex-wrap gap-3 text-sm">
          <Link href="/" className="text-violet-300 hover:text-zinc-200">
            Home →
          </Link>
          <Link href="/internal/entitlements" className="text-zinc-500 hover:text-zinc-300">
            Entitlements →
          </Link>
          <Link
            href="/internal/open-loop-performance"
            className="text-zinc-500 hover:text-zinc-300"
          >
            Open-loop performance →
          </Link>
        </div>
      </div>
    </div>
  );
}
