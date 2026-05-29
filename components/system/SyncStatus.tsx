"use client";

import { useEffect, useState } from "react";
import { Cloud, CloudOff, Loader2, RefreshCw } from "lucide-react";

import { Button } from "@/components/ui/button";
import {
  flushJournalSyncQueue,
  getClientJournalSyncStatus,
  type ClientJournalSyncStatus,
} from "@/lib/persistence/journal-sync-engine";
import { cn } from "@/lib/utils";

import { StatusBadge } from "./StatusBadge";

const COPY: Record<
  ClientJournalSyncStatus,
  { label: string; detail: string; tone: "neutral" | "success" | "warning" | "error" }
> = {
  local_only: {
    label: "On this device",
    detail: "Sign in to back up encrypted entries to your account.",
    tone: "neutral",
  },
  pending_sync: {
    label: "Syncing",
    detail: "Your latest entries are uploading securely.",
    tone: "warning",
  },
  synced: {
    label: "Backed up",
    detail: "Encrypted copy stored with your signed-in account.",
    tone: "success",
  },
  sync_failed: {
    label: "Sync paused",
    detail: "We will retry automatically. You can also retry now.",
    tone: "error",
  },
};

export function SyncStatus({ className, compact = false }: { className?: string; compact?: boolean }) {
  const [status, setStatus] = useState<ClientJournalSyncStatus>("local_only");
  const [retrying, setRetrying] = useState(false);

  useEffect(() => {
    const refresh = () => setStatus(getClientJournalSyncStatus());
    refresh();
    const id = window.setInterval(refresh, 4000);
    return () => window.clearInterval(id);
  }, []);

  useEffect(() => {
    if (status === "pending_sync" || status === "sync_failed") {
      void flushJournalSyncQueue().then(() => setStatus(getClientJournalSyncStatus()));
    }
  }, [status]);

  const meta = COPY[status];
  const Icon =
    status === "synced"
      ? Cloud
      : status === "sync_failed"
        ? CloudOff
        : status === "pending_sync"
          ? Loader2
          : Cloud;

  const handleRetry = async () => {
    setRetrying(true);
    await flushJournalSyncQueue();
    setStatus(getClientJournalSyncStatus());
    setRetrying(false);
  };

  if (compact) {
    return (
      <p role="status" className={cn("text-center text-xs text-zinc-500", className)} data-sync-status={status}>
        {meta.label} — {meta.detail}
      </p>
    );
  }

  return (
    <div
      role="status"
      className={cn(
        "flex flex-col gap-3 rounded-2xl border border-white/10 bg-white/[0.02] px-4 py-3 sm:flex-row sm:items-center sm:justify-between",
        className,
      )}
      data-sync-status={status}
    >
      <div className="flex min-w-0 items-start gap-3">
        <Icon
          className={cn(
            "mt-0.5 h-4 w-4 shrink-0 text-zinc-500",
            status === "pending_sync" && "animate-spin",
            status === "synced" && "text-emerald-400",
            status === "sync_failed" && "text-rose-300",
          )}
          aria-hidden
        />
        <div className="min-w-0">
          <div className="flex flex-wrap items-center gap-2">
            <span className="text-sm font-medium text-zinc-200">Archive sync</span>
            <StatusBadge tone={meta.tone}>{meta.label}</StatusBadge>
          </div>
          <p className="mt-1 text-xs leading-relaxed text-zinc-500">{meta.detail}</p>
        </div>
      </div>
      {status === "sync_failed" ? (
        <Button
          type="button"
          variant="secondary"
          size="sm"
          className="shrink-0 min-h-11"
          disabled={retrying}
          onClick={() => void handleRetry()}
        >
          <RefreshCw className={cn("mr-1.5 h-3.5 w-3.5", retrying && "animate-spin")} aria-hidden />
          Retry sync
        </Button>
      ) : null}
    </div>
  );
}
