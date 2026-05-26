"use client";

import { Button } from "@/components/ui/button";
import { MIC_PERMISSION_COPY } from "@/lib/capture/mic-permission-copy";

export function MicPermissionPanel({ onRetry }: { onRetry: () => void }) {
  return (
    <div className="mx-auto max-w-sm space-y-4 text-center">
      <p className="text-sm leading-relaxed text-zinc-300">
        {MIC_PERMISSION_COPY.primary}
      </p>
      <p className="text-xs leading-relaxed text-zinc-500">
        {MIC_PERMISSION_COPY.braveHint}
      </p>
      <Button
        type="button"
        size="lg"
        className="mobile-touch-target"
        data-primary-cta="retry"
        onClick={onRetry}
      >
        {MIC_PERMISSION_COPY.retry}
      </Button>
    </div>
  );
}
