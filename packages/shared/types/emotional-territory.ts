export type EmotionalTerritoryKind =
  | "work"
  | "family"
  | "relationships"
  | "money"
  | "home"
  | "health"
  | "grief"
  | "identity"
  | "decisions"
  | "rest"
  | "person"
  | "topic";

export interface EmotionalTerritoryEvolution {
  whatChanged: string | null;
  whatCameBack: string | null;
  whatGotQuieter: string | null;
}

export interface EmotionalTerritoryReflection {
  entryId: string;
  dateLabel: string;
  snippet: string;
}

export interface EmotionalTerritory {
  id: string;
  slug: string;
  label: string;
  defaultLabel: string;
  kind: EmotionalTerritoryKind;
  entryIds: string[];
  mentionCount: number;
  continuityLines: string[];
  evolution: EmotionalTerritoryEvolution;
  relatedReflections: EmotionalTerritoryReflection[];
  firstAppearance: string;
  latestAppearance: string;
  firstAppearanceLabel: string;
  latestAppearanceLabel: string;
}

export interface EmotionalTerritoriesReport {
  generatedAt: string;
  hasData: boolean;
  territories: EmotionalTerritory[];
}
