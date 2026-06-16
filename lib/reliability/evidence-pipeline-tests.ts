import assert from "node:assert/strict";
import { readdirSync, readFileSync } from "node:fs";
import { join } from "node:path";

import {
  EVIDENCE_REASON_IDS,
  explainEvidenceReason,
} from "@/lib/evidence/evidence-authority";
import type { EvidencePacket } from "@/lib/evidence/evidence-packet";
import {
  buildEvidencePacket,
  type EvidenceAnalyticsEvent,
  type EvidenceAnalyticsProperties,
  EVIDENCE_ANALYTICS_PROPERTY_KEYS,
  explainEvidenceItem,
  setEvidenceAnalyticsSink,
} from "@/lib/evidence/evidence-pipeline";
import type { EvidenceCandidate } from "@/lib/evidence/evidence-source";
import {
  PROMPT_EVIDENCE_HEADER,
  renderPromptEvidenceContext,
} from "@/lib/evidence/prompt-context-contract";

const NOW = new Date("2026-06-12T12:00:00Z");

function daysAgo(days: number): string {
  return new Date(NOW.getTime() - days * 86_400_000).toISOString();
}

function archive(overrides: Partial<EvidenceCandidate> = {}): EvidenceCandidate {
  return {
    sourceType: "user_archive",
    sourceRef: "entry_a1",
    createdAt: daysAgo(2),
    ...overrides,
  };
}

export async function runEvidencePipelineTests(): Promise<{ failures: string[] }> {
  const failures: string[] = [];

  function check(name: string, fn: () => void): void {
    try {
      fn();
    } catch (error) {
      failures.push(`${name}: ${error instanceof Error ? error.message : String(error)}`);
    } finally {
      setEvidenceAnalyticsSink(null);
    }
  }

  check("generated interpretation is never treated as evidence", () => {
    const { packet, decisions } = buildEvidencePacket(
      [
        {
          sourceType: "generated_interpretation",
          contentSummary: "model output text",
          summaryIsSafe: true,
        },
      ],
      { now: NOW },
    );
    assert.equal(decisions[0].admitted, false);
    assert.equal(decisions[0].influenceLevel, "blocked");
    assert.equal(decisions[0].reasonId, "generated_text");
    assert.equal(packet.items.length, 0);
    assert.equal(packet.blocked_count, 1);
  });

  check("current entry outranks stale archive evidence", () => {
    const { packet } = buildEvidencePacket(
      [
        archive({ sourceRef: "entry_old", createdAt: daysAgo(45) }),
        { sourceType: "current_entry", sourceRef: "entry_now", createdAt: daysAgo(0) },
      ],
      { now: NOW },
    );
    assert.equal(packet.items[0].source_type, "current_entry");
    assert.equal(packet.items[0].influence_level, "compare");
    assert.equal(packet.items[1].source_type, "user_archive");
    assert.equal(packet.items[1].authority_state, "stale");
  });

  check("memory off blocks archive evidence", () => {
    const { packet, decisions } = buildEvidencePacket(
      [
        archive({ userConfirmed: true }),
        { sourceType: "current_entry", sourceRef: "entry_now" },
      ],
      { memoryScope: "off", now: NOW },
    );
    assert.equal(decisions[0].influenceLevel, "blocked");
    assert.equal(decisions[0].reasonId, "memory_off");
    assert.equal(packet.items.length, 1);
    assert.equal(packet.items[0].source_type, "current_entry");
  });

  check("treat-as-new/fresh suppresses archive evidence", () => {
    const { packet, decisions } = buildEvidencePacket(
      [archive({ treatAsNew: true })],
      { now: NOW },
    );
    assert.equal(decisions[0].influenceLevel, "suppress");
    assert.equal(decisions[0].authorityState, "fresh");
    assert.equal(decisions[0].reasonId, "fresh_entry");
    assert.equal(packet.items.length, 0);
  });

  check("ask scope suppresses unapproved archive evidence", () => {
    const { decisions } = buildEvidencePacket(
      [archive(), archive({ sourceRef: "entry_ok", connectionApproved: true })],
      { memoryScope: "ask", now: NOW },
    );
    assert.equal(decisions[0].influenceLevel, "suppress");
    assert.equal(decisions[0].reasonId, "unapproved");
    assert.equal(decisions[1].influenceLevel, "high_authority");
  });

  check("user-confirmed evidence can become high_authority", () => {
    const { packet } = buildEvidencePacket(
      [archive({ userConfirmed: true })],
      { now: NOW },
    );
    assert.equal(packet.items[0].influence_level, "high_authority");
    assert.equal(packet.items[0].authority_state, "confirmed");
    assert.equal(packet.items[0].reason_id, "user_confirmed");
  });

  check("retrieval relevance alone cannot become high_authority", () => {
    const { packet } = buildEvidencePacket(
      [archive({ relevanceScore: 1.0 })],
      { now: NOW },
    );
    assert.equal(packet.items[0].influence_level, "compare");
    assert.notEqual(packet.items[0].influence_level, "high_authority");
  });

  check("conflicting evidence is marked conflicting", () => {
    const { packet } = buildEvidencePacket(
      [archive({ conflictsWithNewer: true })],
      { now: NOW },
    );
    assert.equal(packet.items[0].authority_state, "conflicting");
    assert.equal(packet.items[0].influence_level, "background");
    assert.equal(packet.items[0].reason_id, "mixed_evidence");
  });

  check("superseded evidence is marked superseded", () => {
    const { packet } = buildEvidencePacket(
      [archive({ supersededByNewer: true })],
      { now: NOW },
    );
    assert.equal(packet.items[0].authority_state, "superseded");
    assert.equal(packet.items[0].influence_level, "background");
    assert.equal(packet.items[0].reason_id, "changed_later");
  });

  check("stale evidence is marked stale/background", () => {
    const { packet } = buildEvidencePacket(
      [archive({ createdAt: daysAgo(60) })],
      { now: NOW },
    );
    assert.equal(packet.items[0].authority_state, "stale");
    assert.equal(packet.items[0].influence_level, "background");
    assert.equal(packet.items[0].reason_id, "older_unreinforced");
  });

  check("packet caps at 5 evidence items", () => {
    const candidates = Array.from({ length: 8 }, (_, i) =>
      archive({ sourceRef: `entry_${i}`, createdAt: daysAgo(i) }),
    );
    const { packet } = buildEvidencePacket(candidates, { now: NOW });
    assert.equal(packet.max_items, 5);
    assert.equal(packet.items.length, 5);
    assert.equal(packet.blocked_count, 3);
  });

  check("unknown source type is rejected", () => {
    const { packet, decisions } = buildEvidencePacket(
      [{ sourceType: "mystery_feed", contentSummary: "anything" }],
      { now: NOW },
    );
    assert.equal(decisions[0].sourceType, null);
    assert.equal(decisions[0].influenceLevel, "blocked");
    assert.equal(decisions[0].reasonId, "unknown_source");
    assert.equal(packet.items.length, 0);
  });

  check("packet contains no raw notes/transcripts/snippets/emails/cookies", () => {
    const { packet } = buildEvidencePacket(
      [
        archive({
          sourceRef: "raw note text not an id!!",
          contentSummary: "my private note about a hard decision",
          summaryIsSafe: true,
        }),
        { sourceType: "current_entry", contentSummary: "raw transcript text", summaryIsSafe: true },
        {
          sourceType: "web_result",
          sourceRef: "web_1",
          createdAt: daysAgo(1),
          contentSummary: "Contact me at person@example.com or +1 415 555 0100 via https://leak.example.com",
          summaryIsSafe: true,
          web: {
            url: "https://news.example.com/article",
            domain: "news.example.com",
            title: "Useful article by person@example.com",
          },
        },
        {
          sourceType: "account_state",
          sourceRef: "session=abc123cookie",
          contentSummary: "signed_in",
          summaryIsSafe: true,
        },
      ],
      { now: NOW },
    );

    const serialized = JSON.stringify(packet);
    for (const banned of [
      "private note",
      "raw transcript",
      "person@example.com",
      "555 0100",
      "leak.example.com",
      "abc123cookie",
      "raw note text",
    ]) {
      assert.ok(!serialized.includes(banned), `packet leaked: ${banned}`);
    }
    for (const item of packet.items) {
      assert.equal(item.private_content_redacted, true);
      if (item.source_type === "user_archive" || item.source_type === "current_entry") {
        assert.equal(item.content_summary, null);
      }
    }
  });

  check("analytics/log payload contains no private content", () => {
    const events: { event: EvidenceAnalyticsEvent; props: EvidenceAnalyticsProperties }[] = [];
    setEvidenceAnalyticsSink((event, props) => events.push({ event, props }));

    buildEvidencePacket(
      [
        archive({ contentSummary: "secret note", summaryIsSafe: true }),
        archive({ treatAsNew: true }),
        {
          sourceType: "web_result",
          createdAt: daysAgo(1),
          web: { url: "https://leak.example.com/x", title: "t@e.com" },
        },
        { sourceType: "generated_interpretation" },
      ],
      { now: NOW },
    );

    assert.ok(events.some((e) => e.event === "evidence_packet_built"));
    assert.ok(events.some((e) => e.event === "evidence_item_blocked"));
    assert.ok(events.some((e) => e.event === "evidence_source_used"));
    const allowedKeys = new Set<string>(EVIDENCE_ANALYTICS_PROPERTY_KEYS);
    for (const { props } of events) {
      for (const [key, value] of Object.entries(props)) {
        assert.ok(allowedKeys.has(key), `unexpected analytics key: ${key}`);
        if (typeof value === "string") {
          assert.match(value, /^[a-z0-9_]{1,40}$/, `unsafe analytics value: ${value}`);
          assert.ok(!value.includes("@"));
          assert.ok(!value.includes("http"));
        } else {
          assert.ok(Number.isFinite(value));
        }
      }
    }
  });

  check("empty packet fires evidence_packet_empty", () => {
    const events: EvidenceAnalyticsEvent[] = [];
    setEvidenceAnalyticsSink((event) => events.push(event));
    buildEvidencePacket([archive({ treatAsNew: true })], { now: NOW });
    assert.ok(events.includes("evidence_packet_empty"));
    assert.ok(!events.includes("evidence_packet_built"));
  });

  check("why-this-source-was-used uses stable reason ids only", () => {
    const { packet } = buildEvidencePacket(
      [archive(), archive({ sourceRef: "entry_b2", userConfirmed: true })],
      { now: NOW },
    );
    for (const item of packet.items) {
      const { reasonId, explanation } = explainEvidenceItem(item);
      assert.ok(
        (EVIDENCE_REASON_IDS as readonly string[]).includes(reasonId),
        `unknown reason id: ${reasonId}`,
      );
      assert.ok(explanation.length > 0);
      assert.ok(!explanation.includes("@"));
      assert.ok(!/https?:\/\//.test(explanation));
    }
    // Every reason in the vocabulary has fixed copy.
    for (const reasonId of EVIDENCE_REASON_IDS) {
      assert.ok(explainEvidenceReason(reasonId).length > 0);
    }
  });

  check("generated model text cannot be recycled as evidence", () => {
    const first = buildEvidencePacket(
      [archive({ userConfirmed: true })],
      { now: NOW },
    );
    const explanation = explainEvidenceItem(first.packet.items[0]).explanation;

    // Feeding pipeline output back in as model text is rejected.
    const second = buildEvidencePacket(
      [
        {
          sourceType: "generated_interpretation",
          contentSummary: explanation,
          summaryIsSafe: true,
          userConfirmed: true,
          relevanceScore: 1.0,
        },
      ],
      { now: NOW },
    );
    assert.equal(second.packet.items.length, 0);
    assert.equal(second.decisions[0].reasonId, "generated_text");
  });

  check("account and product state are factual background only", () => {
    const { packet } = buildEvidencePacket(
      [
        { sourceType: "account_state", sourceRef: "signed_in" },
        { sourceType: "product_state", sourceRef: "pro_active" },
      ],
      { now: NOW },
    );
    for (const item of packet.items) {
      assert.equal(item.influence_level, "background");
      assert.equal(item.authority_state, "current");
    }
  });

  check("prompt context renders explicit influence instructions", () => {
    const { packet } = buildEvidencePacket(
      [
        archive({ sourceRef: "entry_hi", userConfirmed: true }),
        archive({ sourceRef: "entry_cmp", createdAt: daysAgo(2) }),
        { sourceType: "account_state", sourceRef: "signed_in" },
      ],
      { now: NOW },
    );
    const context = renderPromptEvidenceContext(packet);
    assert.equal(context.itemCount, 3);
    assert.ok(context.block.startsWith(PROMPT_EVIDENCE_HEADER));
    assert.ok(context.block.includes("influence=high_authority"));
    assert.ok(context.block.includes("Prioritize as user-confirmed evidence"));
    assert.ok(context.block.includes("influence=compare"));
    assert.ok(context.block.includes("Do not present it as established fact"));
    assert.ok(context.block.includes("influence=background"));
    assert.ok(context.block.includes("Background only"));
    assert.ok(
      context.block.includes("If no influence rule allows a connection, do not make one."),
    );
  });

  check("prompt context is empty when there is no evidence", () => {
    const { packet } = buildEvidencePacket([archive({ treatAsNew: true })], { now: NOW });
    const context = renderPromptEvidenceContext(packet);
    assert.equal(context.block, "");
    assert.equal(context.itemCount, 0);
  });

  check("prompt context rejects packets that bypassed the pipeline", () => {
    const { packet } = buildEvidencePacket([archive()], { now: NOW });
    const tamper = (mutate: (copy: EvidencePacket) => void): EvidencePacket => {
      const copy = JSON.parse(JSON.stringify(packet)) as EvidencePacket;
      mutate(copy);
      return copy;
    };

    assert.throws(
      () =>
        renderPromptEvidenceContext(
          tamper((p) => {
            p.items[0].source_type = "generated_interpretation";
          }),
        ),
      /generated text is not evidence/,
    );
    assert.throws(
      () =>
        renderPromptEvidenceContext(
          tamper((p) => {
            p.items[0].influence_level = "blocked";
          }),
        ),
      /non-admitted influence/,
    );
    assert.throws(
      () =>
        renderPromptEvidenceContext(
          tamper((p) => {
            (p.items[0] as { private_content_redacted: boolean }).private_content_redacted =
              false;
          }),
        ),
      /skipped redaction/,
    );
    assert.throws(
      () =>
        renderPromptEvidenceContext(
          tamper((p) => {
            p.items[0].content_summary = "raw archive note text";
          }),
        ),
      /user text in packet/,
    );
    assert.throws(
      () =>
        renderPromptEvidenceContext(
          tamper((p) => {
            p.items[0].source_ref = "not a safe id at all!!";
          }),
        ),
      /unsafe source ref/,
    );
    assert.throws(
      () =>
        renderPromptEvidenceContext(
          tamper((p) => {
            (p.items[0] as { reason_id: string }).reason_id = "made_up_reason";
          }),
        ),
      /unknown reason id/,
    );
  });

  check("prompt context contains no raw user content", () => {
    const { packet } = buildEvidencePacket(
      [
        archive({
          sourceRef: "entry_a1",
          contentSummary: "my secret note about person@example.com",
          summaryIsSafe: true,
        }),
      ],
      { now: NOW },
    );
    const context = renderPromptEvidenceContext(packet);
    assert.ok(!context.block.includes("secret note"));
    assert.ok(!context.block.includes("person@example.com"));
  });

  check("analyze route enforces the prompt context contract", () => {
    const source = readFileSync(
      join(process.cwd(), "app/api/analyze/route.ts"),
      "utf8",
    );
    assert.ok(source.includes("buildEvidencePacket"), "analyze route skips pipeline");
    assert.ok(source.includes("buildPromptContext"), "analyze route skips contract");
    assert.ok(!source.includes("priorContext"), "analyze route accepts loose context");
    assert.ok(!/excerpt/i.test(source), "analyze route accepts raw excerpts");
  });

  check("web clients no longer send raw prior excerpts", () => {
    for (const file of ["components/Recorder.tsx", "lib/pending-reflection.ts"]) {
      const source = readFileSync(join(process.cwd(), file), "utf8");
      assert.ok(!source.includes("priorContext"), `${file} sends loose context`);
      assert.ok(!/excerpt/i.test(source), `${file} sends raw excerpts`);
      assert.ok(
        !source.includes("transcript.slice"),
        `${file} slices transcripts for context`,
      );
    }
  });

  check("no AI route interpolates loose retrieved context", () => {
    const apiRoot = join(process.cwd(), "app/api");
    const routeFiles: string[] = [];
    const walk = (dir: string): void => {
      for (const entry of readdirSync(dir, { withFileTypes: true })) {
        const full = join(dir, entry.name);
        if (entry.isDirectory()) walk(full);
        else if (entry.name === "route.ts") routeFiles.push(full);
      }
    };
    walk(apiRoot);

    for (const file of routeFiles) {
      const source = readFileSync(file, "utf8");
      const callsModel =
        source.includes("chat.completions.create") || source.includes("images.generate");
      if (!callsModel) continue;
      assert.ok(
        !/priorContext|excerpt/i.test(source),
        `${file} interpolates loose retrieved context — route it through the evidence pipeline and prompt context contract`,
      );
    }
  });

  check("web result keeps safe domain/title and redacts contact details", () => {
    const { packet } = buildEvidencePacket(
      [
        {
          sourceType: "web_result",
          createdAt: daysAgo(1),
          web: {
            url: "https://news.example.com/a",
            domain: "https://news.example.com/path?q=1",
            title: "Research notes — write to person@example.com",
          },
        },
      ],
      { now: NOW },
    );
    const item = packet.items[0];
    assert.equal(item.web?.domain, "news.example.com");
    assert.ok(item.web?.title && !item.web.title.includes("person@example.com"));
    assert.equal(item.web?.url, "https://news.example.com/a");
  });

  return { failures };
}
