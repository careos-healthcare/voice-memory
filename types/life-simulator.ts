export type LifeSimulatorDirection = "negative" | "neutral" | "positive";

export interface LifeSimulatorRequest {
  target: {
    categoryToken: string;
    typeToken: string;
  };
  nodes: Array<{
    id: string;
    typeToken: string;
    weight: number;
  }>;
  edges: Array<{
    id: string;
    sourceNodeId: string;
    targetNodeId: string;
    typeToken: string;
    weight: number;
  }>;
  aggregateTopology: {
    nodeCount: number;
    edgeCount: number;
    density: number;
    componentCount: number;
  };
  historicalDeltas: Array<{
    windowDays: number;
    affectedId: string;
    metricToken: string;
    delta: number;
  }>;
  externalCorrelationSummaries: Array<{
    signalToken: string;
    direction: LifeSimulatorDirection;
    strength: number;
    sampleSize: number;
    lagDays: number;
  }>;
  citations: Array<{
    handle: string;
    signalToken: string;
    direction: LifeSimulatorDirection;
    strength: number;
    recencyDays: number;
  }>;
}

export type LifeSimulatorHorizonDays = 30 | 90 | 365;

export interface LifeSimulatorMilestone {
  horizonDays: LifeSimulatorHorizonDays;
  narrativeSummary: string;
  projectedConfidence: number;
  stressImpactScore: number;
  healthCorrelation: number | null;
  affectedIds: string[];
  citationHandles: string[];
}

export interface LifeSimulatorTrajectory {
  summary: string;
  milestones: LifeSimulatorMilestone[];
}

export interface LifeSimulatorResult {
  continueTrajectory: LifeSimulatorTrajectory;
  stopOrPivotTrajectory: LifeSimulatorTrajectory;
}
