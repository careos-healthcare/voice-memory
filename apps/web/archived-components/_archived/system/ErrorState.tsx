import { AlertCircle } from "lucide-react";

import { Button } from "@/archived-components/_archived/ui/button";
import { cn } from "@/lib/utils";

export function ErrorState({
  title = "Something went wrong",
  message,
  onRetry,
  className,
}: {
  title?: string;
  message: string;
  onRetry?: () => void;
  className?: string;
}) {
  return (
    <div
      role="alert"
      className={cn(
        "rounded-2xl border border-rose-500/25 bg-rose-500/5 px-5 py-4",
        className,
      )}
    >
      <div className="flex gap-3">
        <AlertCircle className="mt-0.5 h-5 w-5 shrink-0 text-rose-300" aria-hidden />
        <div className="min-w-0 flex-1">
          <p className="text-sm font-medium text-rose-100">{title}</p>
          <p className="mt-1 text-sm leading-relaxed text-rose-100/80">{message}</p>
          {onRetry ? (
            <Button
              type="button"
              variant="secondary"
              size="sm"
              className="mt-3"
              onClick={onRetry}
            >
              Try again
            </Button>
          ) : null}
        </div>
      </div>
    </div>
  );
}
