/**
 * Prompt context — the only shape an AI prompt builder may accept as
 * context: the current entry plus an optional structured evidence
 * packet. Raw memory strings, raw archive entry arrays, raw search
 * result dumps, and generated interpretation are rejected at this
 * boundary, so no vague prompt stuffing can reach interpretation.
 */

import type { EvidencePacket } from "./evidence-packet";
import {
  emptyPromptEvidenceContext,
  type PromptEvidenceContext,
  renderPromptEvidenceContext,
} from "./prompt-context-contract";

declare const promptContextBrand: unique symbol;

export interface PromptCurrentEntry {
  /** The transcript being interpreted — the primary current context. */
  transcript: string;
}

export interface PromptContextInput {
  currentEntry: PromptCurrentEntry;
  evidencePacket?: EvidencePacket;
}

export interface PromptContext {
  readonly [promptContextBrand]: true;
  readonly currentEntry: PromptCurrentEntry;
  /** Rendered, validated evidence block — empty without evidence. */
  readonly evidence: PromptEvidenceContext;
  readonly packet: EvidencePacket | null;
}

const ALLOWED_INPUT_KEYS = new Set(["currentEntry", "evidencePacket"]);

/**
 * Builds the typed prompt context. Throws on any shape that is not
 * "current entry + optional evidence packet" — extra fields are how
 * loose retrieved context would sneak in, so they are errors.
 */
export function buildPromptContext(input: PromptContextInput): PromptContext {
  if (typeof input !== "object" || input === null || Array.isArray(input)) {
    throw new Error("prompt_context: input must be a structured object");
  }
  for (const key of Object.keys(input)) {
    if (!ALLOWED_INPUT_KEYS.has(key)) {
      throw new Error(`prompt_context: unexpected context field "${key}"`);
    }
  }

  const { currentEntry, evidencePacket } = input;
  if (
    typeof currentEntry !== "object" ||
    currentEntry === null ||
    Array.isArray(currentEntry) ||
    typeof currentEntry.transcript !== "string"
  ) {
    throw new Error("prompt_context: currentEntry must be { transcript: string }");
  }

  if (evidencePacket === undefined) {
    return brand(currentEntry, emptyPromptEvidenceContext(), null);
  }
  if (
    typeof evidencePacket !== "object" ||
    evidencePacket === null ||
    Array.isArray(evidencePacket) ||
    !Array.isArray((evidencePacket as EvidencePacket).items)
  ) {
    throw new Error(
      "prompt_context: additional context must be an evidence packet from buildEvidencePacket",
    );
  }

  // Full structural validation — throws on generated interpretation,
  // non-admitted influence, skipped redaction, or unsafe content.
  const evidence = renderPromptEvidenceContext(evidencePacket);
  return brand(currentEntry, evidence, evidencePacket);
}

/** Converter: EvidencePacket -> PromptContext. */
export function promptContextFromPacket(
  packet: EvidencePacket,
  currentEntry: PromptCurrentEntry,
): PromptContext {
  return buildPromptContext({ currentEntry, evidencePacket: packet });
}

/** The user-message body: transcript first, evidence block after. */
export function composePromptUserContent(context: PromptContext): string {
  return context.evidence.block
    ? `${context.currentEntry.transcript}\n\n${context.evidence.block}`
    : context.currentEntry.transcript;
}

/**
 * Metadata-only view for logging: counts and stable ids, never prompt
 * text or content fields.
 */
export interface PromptContextItemMetadata {
  source_type: string;
  authority_state: string;
  influence_level: string;
  reason_id: string;
  redacted: boolean;
}

export interface PromptContextMetadata {
  item_count: number;
  items: PromptContextItemMetadata[];
}

export function promptContextMetadata(context: PromptContext): PromptContextMetadata {
  const items = (context.packet?.items ?? []).map((item) => ({
    source_type: item.source_type,
    authority_state: item.authority_state,
    influence_level: item.influence_level,
    reason_id: item.reason_id,
    redacted: item.private_content_redacted === true,
  }));
  return { item_count: items.length, items };
}

/**
 * Logs prompt context metadata only. The prompt text and any content
 * fields have no path into this payload.
 */
export function logPromptContextMetadata(
  context: PromptContext,
  log: (line: string) => void = (line) => console.info(line),
): void {
  const payload = {
    ts: new Date().toISOString(),
    event: "prompt_context",
    ...promptContextMetadata(context),
  };
  log(`[ArchiveMe] ${JSON.stringify(payload)}`);
}

function brand(
  currentEntry: PromptCurrentEntry,
  evidence: PromptEvidenceContext,
  packet: EvidencePacket | null,
): PromptContext {
  return { currentEntry, evidence, packet } as PromptContext;
}
