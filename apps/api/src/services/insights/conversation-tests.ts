import assert from "node:assert/strict";

import { parseConversationalReply } from "@/src/services/insights/conversation";

export async function runConversationTests(): Promise<{ failures: string[] }> {
  const failures: string[] = [];
  const allowedEntryIds = new Set(["entry-1", "entry-2"]);

  try {
    const parsed = parseConversationalReply(
      JSON.stringify({
        reply: "  You said this last Tuesday.  ",
        citedEntryIds: ["entry-1", "entry-2", "entry-1"],
        groundedness: "grounded",
      }),
      allowedEntryIds,
    );
    assert.equal(parsed.reply, "You said this last Tuesday.");
    assert.deepEqual(parsed.citedEntryIds, ["entry-1", "entry-2"]);
    assert.equal(parsed.groundedness, "grounded");
  } catch (error) {
    failures.push(`valid reply with deduped citations failed: ${error}`);
  }

  try {
    assert.throws(
      () =>
        parseConversationalReply(
          JSON.stringify({
            reply: "You mentioned this before.",
            citedEntryIds: ["entry-999"],
            groundedness: "thin",
          }),
          allowedEntryIds,
        ),
      (error: unknown) =>
        error instanceof Error && error.message.includes("hallucinated"),
    );
  } catch (error) {
    failures.push(`hallucinated citedEntryId failed: ${error}`);
  }

  try {
    assert.throws(
      () =>
        parseConversationalReply(
          JSON.stringify({
            citedEntryIds: ["entry-1"],
            groundedness: "grounded",
          }),
          allowedEntryIds,
        ),
      (error: unknown) =>
        error instanceof Error &&
        error.message === "Conversational reply response missing reply.",
    );
    assert.throws(
      () =>
        parseConversationalReply(
          JSON.stringify({
            reply: "   ",
            citedEntryIds: ["entry-1"],
            groundedness: "grounded",
          }),
          allowedEntryIds,
        ),
      (error: unknown) =>
        error instanceof Error &&
        error.message === "Conversational reply response missing reply.",
    );
  } catch (error) {
    failures.push(`missing/empty reply failed: ${error}`);
  }

  try {
    assert.throws(
      () =>
        parseConversationalReply(
          JSON.stringify({
            reply: "You said this last Tuesday.",
            citedEntryIds: ["entry-1"],
          }),
          allowedEntryIds,
        ),
      (error: unknown) =>
        error instanceof Error &&
        error.message ===
          "Conversational reply response missing valid groundedness.",
    );
    assert.throws(
      () =>
        parseConversationalReply(
          JSON.stringify({
            reply: "You said this last Tuesday.",
            citedEntryIds: ["entry-1"],
            groundedness: "maybe",
          }),
          allowedEntryIds,
        ),
      (error: unknown) =>
        error instanceof Error &&
        error.message ===
          "Conversational reply response missing valid groundedness.",
    );
  } catch (error) {
    failures.push(`missing/invalid groundedness failed: ${error}`);
  }

  try {
    assert.throws(
      () =>
        parseConversationalReply(
          JSON.stringify({
            reply: "You said this last Tuesday.",
            citedEntryIds: "entry-1",
            groundedness: "none",
          }),
          allowedEntryIds,
        ),
      (error: unknown) =>
        error instanceof Error &&
        error.message ===
          "Conversational reply response missing citedEntryIds array.",
    );
  } catch (error) {
    failures.push(`non-array citedEntryIds failed: ${error}`);
  }

  return { failures };
}
