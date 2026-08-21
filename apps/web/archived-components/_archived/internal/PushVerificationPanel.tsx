"use client";

import { useCallback, useEffect, useState } from "react";
import { RefreshCw } from "lucide-react";

import { Button } from "@/archived-components/_archived/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/archived-components/_archived/ui/card";
import {
  buildPushVerificationReport,
  clearPushVerificationStore,
  PUSH_VERIFICATION_DEFAULT_TARGET,
  requestPushVerificationPermission,
  sendPushVerificationNotification,
} from "@/lib/notifications/push-verification";
import type {
  PushVerificationCheckStatus,
  PushVerificationReport,
} from "@/types/push-verification";

function statusClass(status: PushVerificationCheckStatus): string {
  if (status === "PASSING") return "text-emerald-400/90";
  if (status === "FAILING") return "text-red-300/90";
  return "text-zinc-500";
}

function EventLine({
  label,
  event,
}: {
  label: string;
  event: { at: string; title?: string; targetPath?: string } | null;
}) {
  if (!event) {
    return (
      <p className="text-xs text-zinc-600">
        {label}: <span className="text-zinc-500">—</span>
      </p>
    );
  }
  return (
    <p className="text-xs text-zinc-500">
      {label}: {event.at}
      {event.title ? ` · ${event.title}` : ""}
      {event.targetPath ? ` → ${event.targetPath}` : ""}
    </p>
  );
}

export function PushVerificationPanel() {
  const [report, setReport] = useState<PushVerificationReport | null>(null);
  const [targetPath, setTargetPath] = useState(PUSH_VERIFICATION_DEFAULT_TARGET);
  const [message, setMessage] = useState<string | null>(null);

  const refresh = useCallback(() => {
    setReport(buildPushVerificationReport());
  }, []);

  useEffect(() => {
    refresh();
  }, [refresh]);

  const runRefresh = () => {
    setMessage(null);
    refresh();
  };

  const handleRequestPermission = async () => {
    setMessage(null);
    const result = await requestPushVerificationPermission();
    setMessage(`Permission: ${result}`);
    refresh();
  };

  const handleSendTest = () => {
    setMessage(null);
    const result = sendPushVerificationNotification(targetPath);
    if (!result.ok) {
      setMessage(result.reason);
    } else {
      setMessage(`Sent — tap notification to open ${targetPath}`);
    }
    refresh();
  };

  const handleClear = () => {
    clearPushVerificationStore();
    setMessage("Log cleared.");
    refresh();
  };

  if (!report) {
    return (
      <Card className="border-white/10 bg-zinc-900/50">
        <CardContent className="py-8 text-center text-sm text-zinc-500">Loading…</CardContent>
      </Card>
    );
  }

  const { store } = report;

  return (
    <div className="space-y-6" data-testid="push-verification-panel">
      <Card className="border-white/10 bg-zinc-900/50">
        <CardHeader className="pb-2">
          <CardTitle className="text-base text-zinc-200">Verification actions</CardTitle>
          <p className="text-xs text-zinc-500">
            Real browser notifications only — no simulated pass states.
          </p>
        </CardHeader>
        <CardContent className="space-y-4">
          <div className="flex flex-wrap gap-2">
            <Button type="button" size="sm" variant="secondary" onClick={handleRequestPermission}>
              Request permission
            </Button>
            <Button type="button" size="sm" onClick={handleSendTest}>
              Send test notification
            </Button>
            <Button type="button" size="sm" variant="ghost" onClick={runRefresh}>
              <RefreshCw className="h-4 w-4" />
            </Button>
            <Button type="button" size="sm" variant="ghost" onClick={handleClear}>
              Clear log
            </Button>
          </div>
          <label className="block text-xs text-zinc-500">
            Target path on tap
            <input
              className="mt-1 w-full rounded-lg border border-white/10 bg-black/40 px-3 py-2 text-sm text-zinc-200"
              value={targetPath}
              onChange={(e) => setTargetPath(e.target.value)}
            />
          </label>
          {message ? <p className="text-sm text-violet-200/90">{message}</p> : null}
          <p className="text-xs text-zinc-600">
            API: {report.pushApiAvailable ? "available" : "unavailable"} · permission:{" "}
            {report.permission}
          </p>
        </CardContent>
      </Card>

      <Card className="border-white/10 bg-zinc-900/50">
        <CardHeader className="pb-2">
          <CardTitle className="text-base text-zinc-200">Checks</CardTitle>
        </CardHeader>
        <CardContent className="space-y-3">
          {report.checks.map((check) => (
            <div
              key={check.id}
              className="border-b border-white/5 pb-3 last:border-0"
              data-testid={`push-check-${check.id}`}
            >
              <p className={`text-sm font-medium ${statusClass(check.status)}`}>
                {check.label} — {check.status}
              </p>
              <p className="mt-1 text-xs text-zinc-500">{check.detail}</p>
            </div>
          ))}
        </CardContent>
      </Card>

      <Card className="border-white/10 bg-zinc-900/50">
        <CardHeader className="pb-2">
          <CardTitle className="text-base text-zinc-200">Stored events</CardTitle>
        </CardHeader>
        <CardContent className="space-y-2">
          <EventLine label="Last notification sent" event={store.lastNotificationSent} />
          <EventLine label="Last notification delivered" event={store.lastNotificationDelivered} />
          <EventLine label="Last notification opened" event={store.lastNotificationOpened} />
          {store.lastScreenOpened ? (
            <p className="text-xs text-zinc-500">
              Last screen opened: {store.lastScreenOpened.at} · {store.lastScreenOpened.path}
              {store.lastScreenOpened.matchesTarget ? " (match)" : " (mismatch)"}
            </p>
          ) : (
            <p className="text-xs text-zinc-600">
              Last screen opened: <span className="text-zinc-500">—</span>
            </p>
          )}
        </CardContent>
      </Card>

      <p className="text-xs text-zinc-600">
        {report.passingCount} passing · {report.failingCount} failing · {report.unknownCount}{" "}
        unknown · {report.generatedAt}
      </p>
    </div>
  );
}
