import {
  emptyFeedbackSummary,
  mergeFeedbackSummaries,
  type ResurfacingFeedbackSummary,
} from "@/lib/resurfacing/resurfacing-feedback-summary";
import {
  hashResurfacingKey,
} from "@/lib/resurfacing/resurfacing-privacy-hash";
import type { ResurfacingFeedbackKind } from "@/lib/resurfacing/resurfacing-feedback";

const SERVER_SUMMARY_KEY = "voicememory_server_feedback_summary";

let inMemoryServerSummary: ResurfacingFeedbackSummary | null = null;

function isBrowser(): boolean {
  return typeof localStorage !== "undefined";
}

/** Map server hash keys to client phrase-key penalties for scoring. */
function mapServerSummaryToClientKeys(
  server: ResurfacingFeedbackSummary,
  phraseKey: string,
  topicKey: string,
  personKey: string,
): ResurfacingFeedbackSummary {
  const phraseHash = hashResurfacingKey(phraseKey);
  const topicHash = topicKey ? hashResurfacingKey(`topic:${topicKey}`) : "";
  const personHash = personKey ? hashResurfacingKey(`person:${personKey}`) : "";

  const mapped = emptyFeedbackSummary();
  mapped.source = "merged";

  if (phraseHash && server.phrasePenalties[phraseHash]) {
    mapped.phrasePenalties[phraseKey] = server.phrasePenalties[phraseHash];
  }
  if (phraseHash && server.acceptanceBoosts[phraseHash]) {
    mapped.acceptanceBoosts[phraseKey] = server.acceptanceBoosts[phraseHash];
  }
  if (phraseHash && server.clusterRetired[phraseHash]) {
    mapped.clusterRetired[phraseKey] = true;
  }
  if (phraseHash && server.clusterCooldownUntil[phraseHash]) {
    mapped.clusterCooldownUntil[phraseKey] = server.clusterCooldownUntil[phraseHash];
  }
  if (topicHash && server.topicPenalties[topicHash]) {
    mapped.topicPenalties[topicKey] = server.topicPenalties[topicHash];
  }
  if (personHash && server.personPenalties[personHash]) {
    mapped.personPenalties[personKey] = server.personPenalties[personHash];
  }
  mapped.specificityThresholdBoost = server.specificityThresholdBoost;
  mapped.intensityCautious = server.intensityCautious;

  return mapped;
}

export function readLocalFeedbackSummary(): ResurfacingFeedbackSummary {
  if (!isBrowser()) return emptyFeedbackSummary();
  try {
    const raw = localStorage.getItem("voicememory_resurfacing_feedback");
    if (!raw) return emptyFeedbackSummary();
    const parsed = JSON.parse(raw) as {
      penalties?: Record<string, number>;
      topicPenalties?: Record<string, number>;
      personPenalties?: Record<string, number>;
      acceptanceBoosts?: Record<string, number>;
      specificityThresholdBoost?: number;
      intensityCautious?: boolean;
      clusterRetired?: Record<string, boolean>;
      clusterCooldownUntil?: Record<string, string>;
    };
    return {
      phrasePenalties: parsed.penalties ?? {},
      topicPenalties: parsed.topicPenalties ?? {},
      personPenalties: parsed.personPenalties ?? {},
      acceptanceBoosts: parsed.acceptanceBoosts ?? {},
      specificityThresholdBoost: parsed.specificityThresholdBoost ?? 0,
      intensityCautious: Boolean(parsed.intensityCautious),
      clusterRetired: parsed.clusterRetired ?? {},
      clusterCooldownUntil: parsed.clusterCooldownUntil ?? {},
      source: "local",
    };
  } catch {
    return emptyFeedbackSummary();
  }
}

export function cacheServerFeedbackSummary(summary: ResurfacingFeedbackSummary): void {
  inMemoryServerSummary = summary;
  if (!isBrowser()) return;
  try {
    sessionStorage.setItem(SERVER_SUMMARY_KEY, JSON.stringify(summary));
  } catch {
    /* ignore */
  }
}

export function readCachedServerFeedbackSummary(): ResurfacingFeedbackSummary | null {
  if (inMemoryServerSummary) return inMemoryServerSummary;
  if (!isBrowser()) return null;
  try {
    const raw = sessionStorage.getItem(SERVER_SUMMARY_KEY);
    if (!raw) return null;
    return JSON.parse(raw) as ResurfacingFeedbackSummary;
  } catch {
    return null;
  }
}

export function getMergedFeedbackSummary(
  phraseKey?: string,
  topicKey?: string,
  personKey?: string,
): ResurfacingFeedbackSummary {
  const local = readLocalFeedbackSummary();
  const serverRaw = readCachedServerFeedbackSummary();
  if (!serverRaw) return local;

  const serverMapped =
    phraseKey && phraseKey.length > 0
      ? mapServerSummaryToClientKeys(
          serverRaw,
          phraseKey,
          topicKey ?? "",
          personKey ?? "",
        )
      : serverRaw;

  return mergeFeedbackSummaries(local, serverMapped);
}

export async function hydrateServerFeedbackSummary(): Promise<void> {
  if (!isBrowser()) return;
  try {
    const res = await fetch("/api/resurfacing/feedback/summary", {
      credentials: "include",
    });
    if (!res.ok) return;
    const body = (await res.json()) as { summary?: ResurfacingFeedbackSummary };
    if (body.summary) cacheServerFeedbackSummary(body.summary);
  } catch {
    /* offline / signed out */
  }
}

export async function syncResurfacingFeedbackToServer(input: {
  kind: ResurfacingFeedbackKind;
  phraseKey: string;
  topicKey?: string;
  personKey?: string;
  surface: string;
}): Promise<void> {
  if (!isBrowser()) return;
  try {
    await fetch("/api/resurfacing/feedback", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      credentials: "include",
      body: JSON.stringify({
        feedbackType: input.kind,
        phraseKey: input.phraseKey,
        topicKey: input.topicKey,
        personKey: input.personKey,
        surface: input.surface,
      }),
    });
  } catch {
    /* never block UI */
  }
}
