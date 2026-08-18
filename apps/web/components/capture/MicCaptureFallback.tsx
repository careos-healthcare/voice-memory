import { RecordLoadingShell } from "@/components/capture/RecordLoadingShell";

/** Suspense fallback for /record — dark mic shell (layout provides fullscreen chrome). */
export function MicCaptureFallback() {
  return <RecordLoadingShell />;
}
