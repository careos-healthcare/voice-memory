export type EvolvingUnderstandingEventName =
  | "first_working_theory_seen"
  | "evolving_view_card_seen"
  | "what_happens_next_clicked"
  | "discover_after_first_blind_spot_opened"
  | "returned_to_check_archive_view";

export interface EvolvingUnderstandingEvent {
  name: EvolvingUnderstandingEventName;
  at: string;
  meta?: Record<string, string | number | boolean>;
}

export interface EvolvingUnderstandingState {
  firstWorkingTheorySeenAt: string | null;
  returnedToCheckArchiveViewTracked: boolean;
}

export interface EvolvingUnderstandingReport {
  mainQuestion: string;
  firstBlindSpotSeenCount: number;
  evolvingViewCardSeenCount: number;
  whatHappensNextClickCount: number;
  discoverAfterFirstBlindSpotCount: number;
  returnedToCheckArchiveViewCount: number;
  discoverAfterFirstBlindSpotRate: number | null;
  returnedToCheckArchiveViewRate: number | null;
  whatHappensNextClickRate: number | null;
  lines: string[];
}
