export type InterruptionMode =
  | "silence"
  | "quote_first"
  | "contradiction"
  | "change"
  | "recurrence"
  | "one_line";

export interface InterruptionTimingMetrics {
  shown: number;
  suppressed: number;
  ledToRecording: number;
  ledToReading: number;
  silenceChosen: number;
}

export interface InterruptionTimingReport {
  metrics: InterruptionTimingMetrics;
  shouldInterruptNow: boolean;
  shouldStaySilent: boolean;
  bestMode: InterruptionMode;
  recordingEffectivenessPercent: number | null;
  silenceEffectivenessPercent: number | null;
  plain: string;
}
