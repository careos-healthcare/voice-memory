export type VisualTone = "deep-dark" | "soft-dark" | "warm-light" | "dusk" | "morning";

export interface EntryPhotoMeta {
  photoId: string;
  mimeType: string;
  attachedAt: string;
  filename?: string;
  byteLength?: number;
  width?: number;
  height?: number;
  contentHash?: string;
  compressed?: boolean;
}

export interface ArchivePhotoFile {
  entryId: string;
  mimeType: string;
  dataBase64: string;
  filename: string;
  attachedAt: string;
  byteLength?: number;
  contentHash?: string;
}

export interface SoftTimelineSegment {
  id: string;
  periodLabel: string;
  feelingLine: string;
  intensityBand: "quiet" | "steady" | "heavy" | "mixed";
}

export interface SoftEmotionalTimelineReport {
  generatedAt: string;
  hasData: boolean;
  segments: SoftTimelineSegment[];
}
