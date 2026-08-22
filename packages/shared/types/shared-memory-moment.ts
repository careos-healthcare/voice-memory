export type SharedMemoryMomentTemplate =
  | "forgot_sound"
  | "quieter_thought"
  | "changed_over_time";

export type SharedMemoryMomentSource = "entry" | "milestone";

export interface SharedMemoryMomentCopyExample {
  template: SharedMemoryMomentTemplate;
  message: string;
}
