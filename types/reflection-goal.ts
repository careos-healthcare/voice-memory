export type ReflectionGoal = "off" | "when_ready" | "few_per_week" | "most_days";

export interface ReflectionGoalOption {
  value: ReflectionGoal;
  label: string;
  description: string;
}
