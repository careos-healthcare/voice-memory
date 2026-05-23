export type ContinuityDepthKind =
  | "reflections_connecting"
  | "threads_worth_returning"
  | "older_entries_context";

export type ContinuityDepthContext = "homepage" | "memory";

export interface ContinuityDepthIndicator {
  id: string;
  kind: ContinuityDepthKind;
  text: string;
  strength: number;
}

export interface ContinuityDepthReport {
  indicator: ContinuityDepthIndicator | null;
  hasData: boolean;
}

export interface ContinuityDepthCopyExample {
  kind: ContinuityDepthKind;
  message: string;
  whenShown: string;
}
