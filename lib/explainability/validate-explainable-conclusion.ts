import { isUtf16Boundary } from "@/lib/explainability/citations";
import type {
  CanonicalTranscriptSourceMap,
  ExplainableConclusion,
  PriorExactSnippetSourceMap,
  PriorSnippetField,
  TranscriptEvidenceCitation,
} from "@/types/explainability";

export interface ExplainabilityValidation {
  ok: boolean;
  errors: string[];
  conclusion?: ExplainableConclusion;
}

const EMPTY_UNCERTAINTY =
  /^(?:none|n\/?a|no uncertainty|certain|unknown)[.!]?$/i;
const CROSS_RECORDING_CLAIM =
  /\b(across recordings|prior entry|earlier (?:entry|moment|recording)|both (?:entries|moments|recordings)|supplied prior|recurs?|recurring)\b/i;
const PHRASE_EDGE_STOP_WORDS = new Set([
  "a",
  "an",
  "and",
  "but",
  "for",
  "from",
  "i",
  "in",
  "is",
  "it",
  "of",
  "on",
  "or",
  "that",
  "the",
  "this",
  "to",
  "was",
  "with",
]);

export interface ExplainabilityValidationOptions {
  currentEntryId?: string;
  priorSnippetSources?: PriorExactSnippetSourceMap;
  crossRecordingClaim?: boolean;
}

export function confidenceCapForEvidence(
  supportingCount: number,
  counterCount: number,
): number {
  const supportCap =
    supportingCount <= 0
      ? 0
      : supportingCount === 1
        ? 70
        : supportingCount === 2
          ? 85
          : 95;
  return Math.max(0, supportCap - Math.min(counterCount, 3) * 15);
}

export function validateTranscriptEvidenceCitation(
  value: unknown,
  sources: CanonicalTranscriptSourceMap,
  path = "evidence",
  options: ExplainabilityValidationOptions = {},
): string[] {
  const errors: string[] = [];
  if (!isRecord(value)) return [`${path}: citation must be an object`];

  const entryId = value.sourceEntryId ?? value.entryId;
  const quote = value.exactQuote ?? value.quote;
  const start = value.startUtf16;
  const end = value.endUtf16;
  const role = value.role;
  const confidenceScore = value.confidenceScore ?? 1;
  const audioTimestampMs = value.audioTimestampMs;
  if (typeof entryId !== "string" || !entryId)
    errors.push(`${path}: entryId required`);
  if (typeof quote !== "string" || !quote)
    errors.push(`${path}: non-empty quote required`);
  if (
    typeof confidenceScore !== "number" ||
    confidenceScore < 0 ||
    confidenceScore > 1
  ) {
    errors.push(`${path}: confidenceScore must be between 0 and 1`);
  }
  if (
    audioTimestampMs != null &&
    (!Number.isInteger(audioTimestampMs) || (audioTimestampMs as number) < 0)
  ) {
    errors.push(`${path}: audioTimestampMs must be a non-negative integer`);
  }
  if (
    value.sourceEntryId != null &&
    value.entryId != null &&
    value.sourceEntryId !== value.entryId
  ) {
    errors.push(`${path}: sourceEntryId must equal entryId`);
  }
  if (
    value.exactQuote != null &&
    value.quote != null &&
    value.exactQuote !== value.quote
  ) {
    errors.push(`${path}: exactQuote must equal quote`);
  }
  if (!Number.isInteger(start))
    errors.push(`${path}: startUtf16 must be an integer`);
  if (!Number.isInteger(end))
    errors.push(`${path}: endUtf16 must be an integer`);
  if (role !== "support" && role !== "counter" && role !== "context") {
    errors.push(`${path}: invalid evidence role`);
  }
  if (errors.length) return errors;

  const sourceScope = value.sourceScope ?? "current_transcript";
  let transcript: string | undefined;
  if (sourceScope === "current_transcript") {
    if (
      options.currentEntryId != null &&
      (entryId as string) !== options.currentEntryId
    ) {
      return [`${path}: current transcript citation must use current entryId`];
    }
    transcript = sources.get(entryId as string);
  } else if (sourceScope === "prior_exact_snippet") {
    const sourceField = value.sourceField;
    if (
      sourceField !== "exactLanguagePattern" &&
      sourceField !== "concreteObservation"
    ) {
      return [`${path}: prior exact snippet citation requires sourceField`];
    }
    transcript = options.priorSnippetSources?.get(entryId as string)?.[
      sourceField as PriorSnippetField
    ];
  } else {
    return [`${path}: invalid citation sourceScope`];
  }
  if (transcript == null) {
    return [
      sourceScope === "prior_exact_snippet"
        ? `${path}: unknown admitted prior exact snippet`
        : `${path}: unknown entryId ${entryId as string}`,
    ];
  }
  const startOffset = start as number;
  const endOffset = end as number;
  if (
    startOffset < 0 ||
    endOffset <= startOffset ||
    endOffset > transcript.length
  ) {
    return [`${path}: offsets out of bounds`];
  }
  if (
    !isUtf16Boundary(transcript, startOffset) ||
    !isUtf16Boundary(transcript, endOffset)
  ) {
    errors.push(`${path}: offsets split a UTF-16 surrogate pair`);
  }
  if (transcript.slice(startOffset, endOffset) !== quote) {
    errors.push(
      sourceScope === "prior_exact_snippet"
        ? `${path}: quote does not exactly equal bounded prior snippet slice`
        : `${path}: quote does not exactly equal canonical transcript slice`,
    );
  }
  return errors;
}

export function validateExplainableConclusion(
  value: unknown,
  sources: CanonicalTranscriptSourceMap,
  path = "conclusion",
  options: ExplainabilityValidationOptions = {},
): ExplainabilityValidation {
  const errors: string[] = [];
  if (!isRecord(value))
    return { ok: false, errors: [`${path}: must be an object`] };

  if (typeof value.id !== "string" || !value.id.trim())
    errors.push(`${path}: id required`);
  if (typeof value.statement !== "string" || !value.statement.trim()) {
    errors.push(`${path}: statement required`);
  }
  if (
    !Number.isInteger(value.confidence) ||
    value.confidence !== value.confidencePercent
  ) {
    errors.push(`${path}: confidence must equal confidencePercent`);
  }
  if (
    !Array.isArray(value.reasoning) ||
    value.reasoning.length === 0 ||
    value.reasoning.some(
      (step) => typeof step !== "string" || step.trim().length < 8,
    )
  ) {
    errors.push(`${path}: step-by-step reasoning required`);
  }
  if (
    !Number.isInteger(value.confidencePercent) ||
    (value.confidencePercent as number) < 0 ||
    (value.confidencePercent as number) > 100
  ) {
    errors.push(`${path}: confidencePercent must be an integer from 0 to 100`);
  }
  if (
    value.theoryId != null &&
    (typeof value.theoryId !== "string" ||
      !/^[a-zA-Z0-9_.:-]{1,128}$/.test(value.theoryId))
  ) {
    errors.push(`${path}: theoryId must be a stable safe identifier`);
  }
  if (value.evolutionHistory != null) {
    if (!value.theoryId) {
      errors.push(`${path}: evolutionHistory requires theoryId`);
    }
    if (
      !Array.isArray(value.evolutionHistory) ||
      value.evolutionHistory.length === 0 ||
      value.evolutionHistory.length > 52
    ) {
      errors.push(`${path}: evolutionHistory must contain 1–52 snapshots`);
    } else {
      let priorDate = 0;
      value.evolutionHistory.forEach((snapshot, index) => {
        const snapshotPath = `${path}.evolutionHistory[${index}]`;
        if (!isRecord(snapshot)) {
          errors.push(`${snapshotPath}: snapshot must be an object`);
          return;
        }
        const timestamp =
          typeof snapshot.date === "string"
            ? Date.parse(snapshot.date)
            : Number.NaN;
        if (Number.isNaN(timestamp) || timestamp < priorDate) {
          errors.push(`${snapshotPath}: date must be chronological ISO-8601`);
        }
        priorDate = timestamp;
        if (
          !Number.isInteger(snapshot.confidenceScore) ||
          Number(snapshot.confidenceScore) < 0 ||
          Number(snapshot.confidenceScore) > 100
        ) {
          errors.push(`${snapshotPath}: confidenceScore must be 0–100`);
        }
        if (
          typeof snapshot.deltaReasoning !== "string" ||
          snapshot.deltaReasoning.trim().length < 8
        ) {
          errors.push(`${snapshotPath}: deltaReasoning is required`);
        }
        errors.push(
          ...validateTranscriptEvidenceCitation(
            snapshot.triggeringEvidence,
            sources,
            `${snapshotPath}.triggeringEvidence`,
            options,
          ),
        );
      });
      const latest = value.evolutionHistory.at(-1);
      if (
        isRecord(latest) &&
        latest.confidenceScore !== value.confidencePercent
      ) {
        errors.push(
          `${path}: latest evolution confidence must equal confidencePercent`,
        );
      }
    }
  }
  if (
    typeof value.uncertainty !== "string" ||
    value.uncertainty !== value.uncertaintyNote ||
    typeof value.uncertaintyNote !== "string" ||
    value.uncertaintyNote.trim().length < 12 ||
    EMPTY_UNCERTAINTY.test(value.uncertaintyNote.trim())
  ) {
    errors.push(`${path}: meaningful uncertaintyNote required`);
  }

  const evidence = Array.isArray(value.evidence) ? value.evidence : [];
  if (!Array.isArray(value.evidence) || evidence.length === 0) {
    errors.push(`${path}: evidence required`);
  }
  evidence.forEach((citation, index) => {
    errors.push(
      ...validateTranscriptEvidenceCitation(
        citation,
        sources,
        `${path}.evidence[${index}]`,
        options,
      ),
    );
  });
  const supportingCount = evidence.filter(
    (item): item is TranscriptEvidenceCitation =>
      isRecord(item) && item.role === "support",
  ).length;
  const counterCount = evidence.filter(
    (item) => isRecord(item) && item.role === "counter",
  ).length;
  if (supportingCount === 0)
    errors.push(`${path}: supporting evidence required`);
  const currentSupport = evidence.some(
    (item) =>
      isRecord(item) &&
      item.role === "support" &&
      (item.sourceScope == null || item.sourceScope === "current_transcript") &&
      (options.currentEntryId == null ||
        item.entryId === options.currentEntryId),
  );
  if (!currentSupport)
    errors.push(`${path}: current transcript support required`);
  const crossRecordingClaim =
    options.crossRecordingClaim === true ||
    (typeof value.statement === "string" &&
      CROSS_RECORDING_CLAIM.test(value.statement));
  if (crossRecordingClaim) {
    const currentSupportQuotes = evidence.flatMap((item) =>
      isRecord(item) &&
      item.role === "support" &&
      (item.sourceScope == null || item.sourceScope === "current_transcript") &&
      typeof item.quote === "string"
        ? [item.quote]
        : [],
    );
    const priorSupportQuotes = evidence.flatMap((item) =>
      isRecord(item) &&
      item.role === "support" &&
      item.sourceScope === "prior_exact_snippet" &&
      typeof item.quote === "string"
        ? [item.quote]
        : [],
    );
    const priorSupportIds = new Set(
      evidence.flatMap((item) =>
        isRecord(item) &&
        item.role === "support" &&
        item.sourceScope === "prior_exact_snippet" &&
        typeof item.entryId === "string"
          ? [item.entryId]
          : [],
      ),
    );
    if (
      priorSupportIds.size === 0 ||
      (options.currentEntryId != null &&
        priorSupportIds.has(options.currentEntryId))
    ) {
      errors.push(
        `${path}: cross-recording claim requires current and prior support from distinct entryIds`,
      );
    }
    if (!hasSharedExactPhrase(currentSupportQuotes, priorSupportQuotes)) {
      errors.push(
        `${path}: cross-recording support must share exact recurring behavioral phrasing`,
      );
    }
  }
  if (Number.isInteger(value.confidencePercent)) {
    const cap = Math.min(
      confidenceCapForEvidence(supportingCount, counterCount),
      crossRecordingClaim ? 85 : 95,
    );
    if ((value.confidencePercent as number) > cap) {
      errors.push(`${path}: confidencePercent exceeds evidence cap ${cap}`);
    }
  }

  const alternatives = Array.isArray(value.alternatives)
    ? value.alternatives
    : [];
  if (alternatives.length === 0)
    errors.push(`${path}: at least one alternative required`);
  alternatives.forEach((alternative, index) => {
    if (
      !isRecord(alternative) ||
      typeof alternative.statement !== "string" ||
      alternative.statement.trim().length < 3 ||
      typeof alternative.reason !== "string" ||
      alternative.reason.trim().length < 8
    ) {
      errors.push(
        `${path}.alternatives[${index}]: meaningful statement and reason required`,
      );
    } else if (
      typeof value.statement === "string" &&
      alternative.statement.trim().toLowerCase() ===
        value.statement.trim().toLowerCase()
    ) {
      errors.push(
        `${path}.alternatives[${index}]: must differ from conclusion`,
      );
    }
  });
  if (
    !isRecord(value.alternativeExplanation) ||
    value.alternativeExplanation.statement !== alternatives[0]?.statement ||
    value.alternativeExplanation.reason !== alternatives[0]?.reason
  ) {
    errors.push(
      `${path}: alternativeExplanation must equal the primary alternative`,
    );
  }

  if (
    !isRecord(value.provenance) ||
    (value.provenance.generatedBy !== "model" &&
      value.provenance.generatedBy !== "deterministic") ||
    typeof value.provenance.generatedAt !== "string" ||
    !value.provenance.generatedAt.trim() ||
    !isIsoTimestamp(value.provenance.generatedAt) ||
    value.provenance.schemaVersion !== 4
  ) {
    errors.push(`${path}: valid provenance required`);
  } else {
    if (
      value.provenance.model != null &&
      typeof value.provenance.model !== "string"
    ) {
      errors.push(`${path}.provenance: model must be a string`);
    }
    if (
      value.provenance.promptVersion != null &&
      typeof value.provenance.promptVersion !== "string"
    ) {
      errors.push(`${path}.provenance: promptVersion must be a string`);
    }
    if (
      value.provenance.sourceRevision != null &&
      typeof value.provenance.sourceRevision !== "string"
    ) {
      errors.push(`${path}.provenance: sourceRevision must be a string`);
    }
  }
  if (value.history != null && !Array.isArray(value.history)) {
    errors.push(`${path}: history must be an array`);
  } else if (Array.isArray(value.history)) {
    const events = new Set([
      "created",
      "revised",
      "confidence_changed",
      "evidence_changed",
    ]);
    value.history.forEach((event, index) => {
      if (
        !isRecord(event) ||
        typeof event.recordedAt !== "string" ||
        !isIsoTimestamp(event.recordedAt) ||
        typeof event.event !== "string" ||
        !events.has(event.event)
      ) {
        errors.push(`${path}.history[${index}]: invalid history event`);
      }
    });
  }

  return errors.length
    ? { ok: false, errors }
    : {
        ok: true,
        errors: [],
        conclusion: value as unknown as ExplainableConclusion,
      };
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return value != null && typeof value === "object" && !Array.isArray(value);
}

function hasSharedExactPhrase(current: string[], prior: string[]): boolean {
  const currentPhrases = new Set(current.flatMap(exactEvidencePhrases));
  return prior.some((quote) =>
    exactEvidencePhrases(quote).some((phrase) => currentPhrases.has(phrase)),
  );
}

function exactEvidencePhrases(text: string): string[] {
  const words = text
    .toLowerCase()
    .replace(/[^a-z0-9'\s]/g, " ")
    .split(/\s+/)
    .filter(Boolean);
  const phrases: string[] = [];
  for (let size = Math.min(5, words.length); size >= 2; size -= 1) {
    for (let index = 0; index <= words.length - size; index += 1) {
      const slice = words.slice(index, index + size);
      if (
        PHRASE_EDGE_STOP_WORDS.has(slice[0]!) ||
        PHRASE_EDGE_STOP_WORDS.has(slice.at(-1)!)
      ) {
        continue;
      }
      phrases.push(slice.join(" "));
    }
  }
  return phrases;
}

function isIsoTimestamp(value: string): boolean {
  return (
    /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{2}:\d{2})$/.test(
      value,
    ) && Number.isFinite(Date.parse(value))
  );
}
