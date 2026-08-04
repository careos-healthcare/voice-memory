export type TruthAnchor =
  | {
      kind: "node";
      id: string;
      label: string;
      category: string;
      origin: "manual" | "external";
      confidence: 100;
      note?: string;
      source?: "apple_health" | "spotify";
      observedAt?: string;
    }
  | {
      kind: "edge";
      id: string;
      sourceNodeId: string;
      targetNodeId: string;
      relation: string;
      origin: "manual" | "external";
      confidence: 100;
      note?: string;
      source?: "apple_health" | "spotify";
      observedAt?: string;
    };

export function parseTruthAnchors(value: unknown): TruthAnchor[] {
  if (value == null) return [];
  if (!Array.isArray(value) || value.length > 100) {
    throw new Error("truthAnchors must be an array of at most 100 items");
  }
  return value.map((raw, index) => {
    if (!raw || typeof raw !== "object") {
      throw new Error(`truthAnchors[${index}] must be an object`);
    }
    const item = raw as Record<string, unknown>;
    if (
      (item.origin !== "manual" && item.origin !== "external") ||
      item.confidence !== 100 ||
      typeof item.id !== "string" ||
      item.id.length === 0
    ) {
      throw new Error(`truthAnchors[${index}] is not a locked truth anchor`);
    }
    if (
      item.origin === "external" &&
      ((item.source !== "apple_health" && item.source !== "spotify") ||
        typeof item.observedAt !== "string" ||
        !Number.isFinite(Date.parse(item.observedAt)))
    ) {
      throw new Error(
        `truthAnchors[${index}] external source metadata is invalid`,
      );
    }
    if (
      item.kind === "node" &&
      typeof item.label === "string" &&
      typeof item.category === "string"
    ) {
      return item as TruthAnchor;
    }
    if (
      item.kind === "edge" &&
      typeof item.sourceNodeId === "string" &&
      typeof item.targetNodeId === "string" &&
      typeof item.relation === "string"
    ) {
      return item as TruthAnchor;
    }
    throw new Error(`truthAnchors[${index}] has an invalid shape`);
  });
}

export function buildTruthAnchorContext(anchors: TruthAnchor[]): string {
  if (anchors.length === 0) return "";
  return [
    "TRUTH ANCHORS (explicit and passively observed ground truth):",
    "Treat these locked anchors as absolute ground-truth context (100% confidence) that overrides conflicting extracted audio. Manual anchors are user-defined; external anchors are factual sensor or listening observations. They are context, not transcript evidence; never fabricate an audio citation for them.",
    ...anchors.map((anchor) =>
      anchor.kind === "node"
        ? `- NODE ${anchor.id} | ${anchor.category} | ${anchor.label}${anchor.source ? ` | source: ${anchor.source}` : ""}${anchor.observedAt ? ` | observed: ${anchor.observedAt}` : ""}${anchor.note ? ` | note: ${anchor.note}` : ""}`
        : `- EDGE ${anchor.id} | ${anchor.sourceNodeId} -[${anchor.relation}]-> ${anchor.targetNodeId}${anchor.source ? ` | source: ${anchor.source}` : ""}${anchor.observedAt ? ` | observed: ${anchor.observedAt}` : ""}${anchor.note ? ` | note: ${anchor.note}` : ""}`,
    ),
  ].join("\n");
}
