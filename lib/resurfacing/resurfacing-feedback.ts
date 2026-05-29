import { isSideEffectBlocked } from "@/lib/tracking/presentation-guard";

import type { ResurfacingMetricName } from "@/lib/resurfacing/resurfacing-metrics";

const FEEDBACK_KEY = "voicememory_resurfacing_feedback";
const COOLDOWN_KEY = "voicememory_resurfacing_cooldowns";

export type ResurfacingFeedbackKind =
  | "not_me"
  | "missed"
  | "dismissed"
  | "that_fits"
  | "wrong_topic"
  | "wrong_person"
  | "too_intense"
  | "too_vague"
  | "already_know"
  | "show_less";

export interface ResurfacingFeedbackEvent {
  at: string;
  kind: ResurfacingFeedbackKind;
  phraseKey: string;
  topicKey?: string;
  personKey?: string;
  surface: "first_return" | "callback" | "thread";
}

interface FeedbackStore {
  events: ResurfacingFeedbackEvent[];
  penalties: Record<string, number>;
  topicPenalties: Record<string, number>;
  personPenalties: Record<string, number>;
  acceptanceBoosts: Record<string, number>;
  clusterCooldownUntil: Record<string, string>;
  clusterRetired: Record<string, boolean>;
  specificityThresholdBoost: number;
  intensityCautious: boolean;
}

interface CooldownStore {
  until: Record<string, string>;
}

export const PENALTY_NOT_ME = 35;
const PENALTY_MISSED = 12;
const PENALTY_DISMISSED = 8;
const PENALTY_WRONG_TOPIC = 28;
const PENALTY_WRONG_PERSON = 30;
const PENALTY_TOO_INTENSE = 10;
const PENALTY_TOO_VAGUE = 8;
const PENALTY_ALREADY_KNOW = 22;
const PENALTY_SHOW_LESS = 18;
const BOOST_THAT_FITS = 12;
const COOLDOWN_DAYS_NOT_ME = 30;
const COOLDOWN_DAYS_SHOW_LESS = 14;
const COOLDOWN_DAYS_ALREADY_KNOW = 21;
const SPECIFICITY_BOOST_PER_TOO_VAGUE = 6;

function isBrowser(): boolean {
  return typeof localStorage !== "undefined";
}

function normalizePhraseKey(raw: string): string {
  return raw
    .toLowerCase()
    .replace(/[^\w\s']/g, " ")
    .replace(/\s+/g, " ")
    .trim()
    .slice(0, 80);
}

export function phraseKeyFromQuote(quote: string): string {
  const stripped = quote.replace(/^["']|["']$/g, "").trim();
  return normalizePhraseKey(stripped);
}

export function topicKeyFromQuote(quote: string): string {
  const key = phraseKeyFromQuote(quote);
  const topicMatch = key.match(
    /\b(work|job|boss|manager|team|family|mom|dad|partner|health|money|sleep|anxiety)\b/,
  );
  return topicMatch ? topicMatch[1]! : key.slice(0, 32);
}

export function personKeyFromQuote(quote: string): string {
  const names = quote.match(/\b[A-Z][a-z]{2,}\b/g);
  if (names?.length) return names[0]!.toLowerCase();
  return "";
}

function readStore(): FeedbackStore {
  const empty: FeedbackStore = {
    events: [],
    penalties: {},
    topicPenalties: {},
    personPenalties: {},
    acceptanceBoosts: {},
    clusterCooldownUntil: {},
    clusterRetired: {},
    specificityThresholdBoost: 0,
    intensityCautious: false,
  };
  if (!isBrowser()) return empty;
  try {
    const raw = localStorage.getItem(FEEDBACK_KEY);
    if (!raw) return empty;
    const parsed = JSON.parse(raw) as Partial<FeedbackStore>;
    return {
      events: Array.isArray(parsed.events) ? parsed.events.slice(-300) : [],
      penalties:
        parsed.penalties && typeof parsed.penalties === "object"
          ? parsed.penalties
          : {},
      topicPenalties:
        parsed.topicPenalties && typeof parsed.topicPenalties === "object"
          ? parsed.topicPenalties
          : {},
      personPenalties:
        parsed.personPenalties && typeof parsed.personPenalties === "object"
          ? parsed.personPenalties
          : {},
      acceptanceBoosts:
        parsed.acceptanceBoosts && typeof parsed.acceptanceBoosts === "object"
          ? parsed.acceptanceBoosts
          : {},
      clusterCooldownUntil:
        parsed.clusterCooldownUntil && typeof parsed.clusterCooldownUntil === "object"
          ? parsed.clusterCooldownUntil
          : {},
      clusterRetired:
        parsed.clusterRetired && typeof parsed.clusterRetired === "object"
          ? parsed.clusterRetired
          : {},
      specificityThresholdBoost:
        typeof parsed.specificityThresholdBoost === "number"
          ? parsed.specificityThresholdBoost
          : 0,
      intensityCautious: Boolean(parsed.intensityCautious),
    };
  } catch {
    return empty;
  }
}

function writeStore(store: FeedbackStore): void {
  if (!isBrowser() || isSideEffectBlocked()) return;
  localStorage.setItem(
    FEEDBACK_KEY,
    JSON.stringify({
      events: store.events.slice(-300),
      penalties: store.penalties,
      topicPenalties: store.topicPenalties,
      personPenalties: store.personPenalties,
      acceptanceBoosts: store.acceptanceBoosts,
      clusterCooldownUntil: store.clusterCooldownUntil,
      clusterRetired: store.clusterRetired,
      specificityThresholdBoost: store.specificityThresholdBoost,
      intensityCautious: store.intensityCautious,
    }),
  );
}

function readCooldowns(): CooldownStore {
  if (!isBrowser()) return { until: {} };
  try {
    const raw = localStorage.getItem(COOLDOWN_KEY);
    if (!raw) return { until: {} };
    const parsed = JSON.parse(raw) as CooldownStore;
    return { until: parsed.until ?? {} };
  } catch {
    return { until: {} };
  }
}

function writeCooldowns(store: CooldownStore): void {
  if (!isBrowser() || isSideEffectBlocked()) return;
  localStorage.setItem(COOLDOWN_KEY, JSON.stringify(store));
}

function setClusterCooldown(
  store: FeedbackStore,
  phraseKey: string,
  days: number,
  retire = false,
): void {
  const until = new Date();
  until.setDate(until.getDate() + days);
  store.clusterCooldownUntil[phraseKey] = until.toISOString();
  if (retire) store.clusterRetired[phraseKey] = true;
}

function metricForKind(kind: ResurfacingFeedbackKind): ResurfacingMetricName | null {
  switch (kind) {
    case "not_me":
      return "not_me_clicked";
    case "that_fits":
      return "callback_fit_clicked";
    case "wrong_topic":
      return "wrong_topic_clicked";
    case "wrong_person":
      return "wrong_person_clicked";
    case "too_intense":
      return "too_intense_clicked";
    case "too_vague":
      return "too_vague_clicked";
    case "already_know":
      return "already_know_clicked";
    case "show_less":
      return "show_less_like_this_clicked";
    case "missed":
    case "dismissed":
      return "callback_dismissed";
    default:
      return null;
  }
}

export function recordResurfacingFeedback(input: {
  kind: ResurfacingFeedbackKind;
  quote: string;
  surface: ResurfacingFeedbackEvent["surface"];
  topicKey?: string;
  personKey?: string;
}): void {
  if (!isBrowser() || isSideEffectBlocked()) return;

  const phraseKey = phraseKeyFromQuote(input.quote);
  if (!phraseKey) return;

  const topicKey = input.topicKey ?? topicKeyFromQuote(input.quote);
  const personKey = input.personKey ?? personKeyFromQuote(input.quote);
  const store = readStore();

  switch (input.kind) {
    case "not_me":
      store.penalties[phraseKey] = (store.penalties[phraseKey] ?? 0) + PENALTY_NOT_ME;
      setClusterCooldown(store, phraseKey, COOLDOWN_DAYS_NOT_ME, true);
      break;
    case "missed":
    case "dismissed":
      store.penalties[phraseKey] = (store.penalties[phraseKey] ?? 0) + PENALTY_MISSED;
      break;
    case "that_fits":
      store.acceptanceBoosts[phraseKey] = (store.acceptanceBoosts[phraseKey] ?? 0) + BOOST_THAT_FITS;
      if (store.penalties[phraseKey]) {
        store.penalties[phraseKey] = Math.max(0, store.penalties[phraseKey]! - 8);
      }
      break;
    case "wrong_topic":
      store.topicPenalties[topicKey] = (store.topicPenalties[topicKey] ?? 0) + PENALTY_WRONG_TOPIC;
      store.penalties[phraseKey] = (store.penalties[phraseKey] ?? 0) + 14;
      break;
    case "wrong_person":
      if (personKey) {
        store.personPenalties[personKey] =
          (store.personPenalties[personKey] ?? 0) + PENALTY_WRONG_PERSON;
      }
      store.penalties[phraseKey] = (store.penalties[phraseKey] ?? 0) + 16;
      break;
    case "too_intense":
      store.intensityCautious = true;
      store.penalties[phraseKey] = (store.penalties[phraseKey] ?? 0) + PENALTY_TOO_INTENSE;
      break;
    case "too_vague":
      store.specificityThresholdBoost += SPECIFICITY_BOOST_PER_TOO_VAGUE;
      store.penalties[phraseKey] = (store.penalties[phraseKey] ?? 0) + PENALTY_TOO_VAGUE;
      break;
    case "already_know":
      store.penalties[phraseKey] = (store.penalties[phraseKey] ?? 0) + PENALTY_ALREADY_KNOW;
      setClusterCooldown(store, phraseKey, COOLDOWN_DAYS_ALREADY_KNOW);
      break;
    case "show_less":
      store.penalties[phraseKey] = (store.penalties[phraseKey] ?? 0) + PENALTY_SHOW_LESS;
      setClusterCooldown(store, phraseKey, COOLDOWN_DAYS_SHOW_LESS);
      break;
    default:
      break;
  }

  store.events.push({
    at: new Date().toISOString(),
    kind: input.kind,
    phraseKey,
    topicKey,
    personKey: personKey || undefined,
    surface: input.surface,
  });
  writeStore(store);

  if (input.kind === "not_me") {
    const cooldowns = readCooldowns();
    const until = new Date();
    until.setDate(until.getDate() + COOLDOWN_DAYS_NOT_ME);
    cooldowns.until[phraseKey] = until.toISOString();
    writeCooldowns(cooldowns);
  }

  const metric = metricForKind(input.kind);
  if (metric) {
    void import("@/lib/resurfacing/resurfacing-metrics").then((mod) => {
      mod.recordResurfacingMetric(metric, { phraseKey });
    });
  }

  void import("@/lib/resurfacing/merged-feedback-client").then((mod) => {
    void mod.syncResurfacingFeedbackToServer({
      kind: input.kind,
      phraseKey,
      topicKey,
      personKey: personKey || undefined,
      surface: input.surface,
    });
  });
}

export function userFeedbackPenaltyForPhrase(phraseKey: string): number {
  return readStore().penalties[phraseKey] ?? 0;
}

export function userFeedbackBoostForPhrase(phraseKey: string): number {
  return readStore().acceptanceBoosts[phraseKey] ?? 0;
}

export function topicFeedbackPenalty(topicKey: string): number {
  return readStore().topicPenalties[topicKey] ?? 0;
}

export function personFeedbackPenalty(personKey: string): number {
  if (!personKey) return 0;
  return readStore().personPenalties[personKey] ?? 0;
}

export function getSpecificityThresholdBoost(): number {
  return readStore().specificityThresholdBoost;
}

export function isIntensityCautiousFromFeedback(): boolean {
  return readStore().intensityCautious;
}

export function isPhraseOnResurfacingCooldown(phraseKey: string): boolean {
  const until = readCooldowns().until[phraseKey];
  if (until && Date.parse(until) > Date.now()) return true;
  const clusterUntil = readStore().clusterCooldownUntil[phraseKey];
  if (clusterUntil && Date.parse(clusterUntil) > Date.now()) return true;
  return false;
}

export function getClusterCooldownStatus(
  phraseKey: string,
): "clear" | "cooldown" | "fatigued" | "retired" {
  const store = readStore();
  if (store.clusterRetired[phraseKey]) return "retired";
  const until = store.clusterCooldownUntil[phraseKey];
  if (until && Date.parse(until) > Date.now()) return "cooldown";
  if (isPhraseOnResurfacingCooldown(phraseKey)) return "cooldown";
  return "clear";
}

export function listResurfacingFeedbackEvents(): ResurfacingFeedbackEvent[] {
  return readStore().events;
}

export function clearResurfacingFeedbackForEval(): void {
  if (!isBrowser()) return;
  localStorage.removeItem(FEEDBACK_KEY);
  localStorage.removeItem(COOLDOWN_KEY);
}
