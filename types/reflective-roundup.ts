export type RoundupPeriodKind = "weekly" | "monthly" | "custom";

export type ReflectiveRoundupSignal =
  | "returned"
  | "faded"
  | "tone_shift"
  | "clearer"
  | "unfinished"
  | "heavier"
  | "lighter"
  | "revisited"
  | "carried_differently";

export interface RoundupPeriod {
  kind: RoundupPeriodKind;
  startDayKey: string;
  endDayKey: string;
  label: string;
  slug: string;
}

export interface ReflectiveRoundupLine {
  id: string;
  text: string;
  entryIds: string[];
  signal: ReflectiveRoundupSignal;
  score: number;
}

export interface ReflectiveRoundup {
  period: RoundupPeriod;
  generatedAt: string;
  lines: ReflectiveRoundupLine[];
  hasData: boolean;
}

export interface RoundupIndexItem {
  period: RoundupPeriod;
  previewLine?: string;
  hasData: boolean;
}

export interface RoundupListReport {
  generatedAt: string;
  items: RoundupIndexItem[];
}

export type KeyPieceKind =
  | "repeated_concern"
  | "named_entity"
  | "decision"
  | "unresolved_question"
  | "phrase_repeated"
  | "wanted_thing"
  | "avoided_naming"
  | "worth_revisiting";

export interface KeyPiece {
  id: string;
  text: string;
  entryId: string;
  kind: KeyPieceKind;
}

export interface KeyPiecesReport {
  items: KeyPiece[];
  hasData: boolean;
}
