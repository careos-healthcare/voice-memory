"use client";

import { Download } from "lucide-react";

import { Button } from "@/components/ui/button";
import { trackLaunchEvent, LAUNCH_EVENTS } from "@/lib/local-analytics";
import {
  buildInsightsSummaryText,
  buildWeeklySummaryText,
  downloadTextFile,
  slugExportDate,
} from "@/lib/memory-export";

interface ExportSummaryButtonProps {
  variant: "weekly" | "timeline";
  className?: string;
}

export function ExportSummaryButton({
  variant,
  className,
}: ExportSummaryButtonProps) {
  const handleExport = () => {
    const date = slugExportDate();
    trackLaunchEvent(LAUNCH_EVENTS.exportUsed, { variant });
    if (variant === "weekly") {
      downloadTextFile(`voicememory-weekly-${date}.txt`, buildWeeklySummaryText());
      return;
    }
    downloadTextFile(`voicememory-timeline-${date}.txt`, buildInsightsSummaryText());
  };

  return (
    <Button
      type="button"
      variant="secondary"
      size="sm"
      className={className}
      onClick={handleExport}
    >
      <Download className="h-4 w-4" />
      Export {variant === "weekly" ? "weekly" : "timeline"} summary
    </Button>
  );
}
