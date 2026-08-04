export type ActionPlanSourceType =
  | "simulation_trajectory"
  | "semantic_cluster";

export type ActionPlanHorizonDays = 30 | 90 | 365;

export interface ActionPlanNode {
  id: string;
  typeToken: string;
  weight: number;
}

export interface ActionPlanEdge {
  id: string;
  sourceNodeId: string;
  targetNodeId: string;
  typeToken: string;
  weight: number;
}

export interface ActionPlanAggregateMetric {
  metricToken: string;
  value: number;
}

interface ActionPlanRequestBase {
  nodes: ActionPlanNode[];
  edges: ActionPlanEdge[];
  aggregateMetrics: ActionPlanAggregateMetric[];
}

export interface SimulationTrajectoryActionPlanRequest
  extends ActionPlanRequestBase {
  source: "simulation_trajectory";
  trajectoryData: Array<{
    horizonDays: ActionPlanHorizonDays;
    value: number;
  }>;
}

export interface SemanticClusterActionPlanRequest extends ActionPlanRequestBase {
  source: "semantic_cluster";
  clusterData: {
    categoryToken: string;
    cohesion: number;
    activity: number;
  };
}

export type ActionPlanGeneratorRequest =
  | SimulationTrajectoryActionPlanRequest
  | SemanticClusterActionPlanRequest;

export type ActionPlanFrequency = "daily" | "custom_days";

export type ActionPlanWeekday =
  | "monday"
  | "tuesday"
  | "wednesday"
  | "thursday"
  | "friday"
  | "saturday"
  | "sunday";

export interface ActionPlanMicroHabit {
  title: string;
  frequency: ActionPlanFrequency;
  customWeekdays: ActionPlanWeekday[];
  targetNodeId: string;
  stackingCue: string | null;
}

export interface ActionPlanGeneratorResult {
  planTitle: string;
  targetOutcome: string;
  microHabits: [
    ActionPlanMicroHabit,
    ActionPlanMicroHabit,
    ActionPlanMicroHabit,
  ];
}
