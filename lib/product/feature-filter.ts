/**
 * Feature request filter — every future feature must map to activation, return, or conversion.
 */

export type FounderProductPriority = "activation" | "return" | "conversion";

export type FeatureFilterVerdict = "ALIGNED" | "LOW_PRIORITY";

export type FeatureFilterInput = {
  name: string;
  improvesActivation?: boolean;
  improvesReturn?: boolean;
  improvesConversion?: boolean;
};

export type FeatureFilterResult = {
  verdict: FeatureFilterVerdict;
  alignedPriorities: FounderProductPriority[];
  flag: string | null;
};

const LOW_PRIORITY_FLAG =
  "LOW PRIORITY — does not improve activation, return, or conversion";

export function evaluateFeatureRequest(input: FeatureFilterInput): FeatureFilterResult {
  const alignedPriorities: FounderProductPriority[] = [];
  if (input.improvesActivation) alignedPriorities.push("activation");
  if (input.improvesReturn) alignedPriorities.push("return");
  if (input.improvesConversion) alignedPriorities.push("conversion");

  if (alignedPriorities.length === 0) {
    return {
      verdict: "LOW_PRIORITY",
      alignedPriorities: [],
      flag: LOW_PRIORITY_FLAG,
    };
  }

  return {
    verdict: "ALIGNED",
    alignedPriorities,
    flag: null,
  };
}

export function featureFilterLine(result: FeatureFilterResult): string {
  if (result.verdict === "LOW_PRIORITY") return result.flag ?? LOW_PRIORITY_FLAG;
  return `Aligned: ${result.alignedPriorities.join(", ")}`;
}
