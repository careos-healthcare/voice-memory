import { addDaysToKey, todayKey } from "@/lib/dates";
import { syncHabitFromEntries } from "@/lib/habit-storage";
import { trackLaunchEvent, LAUNCH_EVENTS } from "@/lib/local-analytics";
import { setCachedWeeklySummary } from "@/lib/weekly-summary-cache";
import type { JournalEntry, Reflection } from "@/types/journal";

const DEMO_ACTIVE_KEY = "voicememory_demo_active";
const DEMO_BACKUP_KEY = "voicememory_demo_backup";

function isBrowser(): boolean {
  return typeof window !== "undefined";
}

function reflection(
  partial: Partial<Reflection> & Pick<Reflection, "mood" | "emotionalIntensity">,
): Reflection {
  return {
    mood: partial.mood,
    emotionalIntensity: partial.emotionalIntensity,
    recurringThemes: partial.recurringThemes ?? [],
    hiddenConcern: "",
    positiveSignal: "",
    recommendation: "",
    exactLanguagePattern: partial.exactLanguagePattern,
    concreteObservation: partial.concreteObservation,
    repeatedSignal: partial.repeatedSignal,
    tensionOrContradiction: partial.tensionOrContradiction,
    avoidedOrVagueArea: partial.avoidedOrVagueArea,
    nextSmallAction: partial.nextSmallAction,
  };
}

function daysAgoIso(days: number, hour = 9): string {
  const key = addDaysToKey(todayKey(), -days);
  const [y, m, d] = key.split("-").map(Number);
  return new Date(y, m - 1, d, hour, 30, 0).toISOString();
}

function buildDemoEntries(): JournalEntry[] {
  const entries: Array<Omit<JournalEntry, "id"> & { id?: string }> = [
    {
      id: "demo-entry-01",
      createdAt: daysAgoIso(20, 8),
      durationSeconds: 42,
      transcript:
        "Started the week feeling scattered. Sarah called about the project timeline and I noticed my chest tighten — classic anxious response when deadlines stack up. Still, I got one hard thing done before lunch.",
      reflection: reflection({
        mood: "anxious",
        emotionalIntensity: 6,
        recurringThemes: ["work pressure", "deadlines"],
        exactLanguagePattern: "my chest tighten when deadlines stack up",
        concreteObservation:
          "Sarah's call about the project timeline landed as a physical stress response.",
        tensionOrContradiction:
          "You got one hard thing done before lunch, but the timeline call still tightened your chest.",
        repeatedSignal: "Deadlines stacking as the trigger phrase",
        nextSmallAction: "Send Sarah a realistic timeline update by noon tomorrow",
      }),
    },
    {
      id: "demo-entry-02",
      createdAt: daysAgoIso(18, 19),
      durationSeconds: 38,
      transcript:
        "Money came up again — looking at the account after rent and feeling that familiar squeeze. Mum texted about visiting next month and I want to say yes but I'm not sure we can afford the extra trip.",
      reflection: reflection({
        mood: "worried",
        emotionalIntensity: 7,
        recurringThemes: ["money", "family"],
        exactLanguagePattern: "that familiar squeeze after rent",
        concreteObservation:
          "Mum's visit invite landed right after you checked the account post-rent.",
        tensionOrContradiction:
          "You want to say yes to Mum while the post-rent balance says wait.",
        avoidedOrVagueArea:
          "Money 'came up again' without naming what changed in the numbers.",
        repeatedSignal: "Rent-then-squeeze as the money shorthand",
        nextSmallAction: "Draft a one-line budget for Mum's visit tonight",
      }),
    },
    {
      id: "demo-entry-03",
      createdAt: daysAgoIso(16, 7),
      durationSeconds: 51,
      transcript:
        "Actually slept well. Woke up hopeful about the side project — maybe I can ship a small version this month. Told myself I don't need perfection, just something real people can try.",
      reflection: reflection({
        mood: "hopeful",
        emotionalIntensity: 4,
        recurringThemes: ["creative work", "self-trust"],
        exactLanguagePattern: "don't need perfection, just something real",
        concreteObservation:
          "Good sleep preceded clearer optimism about shipping the side project.",
        tensionOrContradiction:
          "Perfectionism is the brake; 'something real people can try' is the release.",
        repeatedSignal: "Shipping vs perfection framing",
        nextSmallAction: "Write three bullet points for the smallest shippable version",
      }),
    },
    {
      id: "demo-entry-04",
      createdAt: daysAgoIso(14, 21),
      durationSeconds: 45,
      transcript:
        "Family pressure showed up at dinner — Dad asking about career plans again. I stayed calm but felt that old knot in my stomach. Grateful I didn't snap. Need to set a boundary about how often we have this conversation.",
      reflection: reflection({
        mood: "conflicted",
        emotionalIntensity: 6,
        recurringThemes: ["family pressure", "boundaries"],
        exactLanguagePattern: "that old knot in my stomach",
        concreteObservation:
          "Dad's career questions still land physically even when you answer calmly.",
        tensionOrContradiction:
          "You stayed calm at dinner while your stomach stayed knotted.",
        repeatedSignal: "Career-plan questions from Dad",
        nextSmallAction: "Practice one redirect sentence before the next family call",
      }),
    },
    {
      id: "demo-entry-05",
      createdAt: daysAgoIso(12, 8),
      durationSeconds: 33,
      transcript:
        "Quick note — anxious again before the standup. Same loop: imagining everyone judging the update. The update went fine. Writing that down so I remember next time.",
      reflection: reflection({
        mood: "anxious",
        emotionalIntensity: 5,
        recurringThemes: ["work anxiety", "self-judgment"],
        exactLanguagePattern: "imagining everyone judging the update",
        concreteObservation:
          "Pre-standup dread did not match how the update actually went.",
        tensionOrContradiction:
          "Same loop before the meeting; fine outcome after.",
        repeatedSignal: "Judgment story before standups",
        nextSmallAction: "After the next standup, write one factual outcome line",
      }),
    },
    {
      id: "demo-entry-06",
      createdAt: daysAgoIso(10, 18),
      durationSeconds: 47,
      transcript:
        "Ran into Alex at the coffee shop — good conversation about changing teams. Mentioned money again indirectly, how a move might affect the mortgage. Feeling clearer that I need numbers before any decision.",
      reflection: reflection({
        mood: "reflective",
        emotionalIntensity: 4,
        recurringThemes: ["career", "money", "relationships"],
        exactLanguagePattern: "need numbers before any decision",
        concreteObservation:
          "Alex's team-change talk surfaced the mortgage as the decision gate.",
        tensionOrContradiction:
          "The conversation felt open; the mortgage constraint stayed unspoken until you named it.",
        avoidedOrVagueArea:
          "Money came up 'indirectly' before you said you need numbers.",
        nextSmallAction: "Write down three financial constraints for a potential team move",
      }),
    },
    {
      id: "demo-entry-07",
      createdAt: daysAgoIso(9, 9),
      durationSeconds: 40,
      transcript:
        "Sarah checked in again — appreciative tone this time. Felt lighter. Still work pressure but less alone in it. Noticed I breathe easier when collaboration feels mutual.",
      reflection: reflection({
        mood: "relieved",
        emotionalIntensity: 3,
        recurringThemes: ["collaboration", "work relationships"],
        exactLanguagePattern: "breathe easier when collaboration feels mutual",
        concreteObservation:
          "Sarah's appreciative check-in dropped the isolation around the project.",
        tensionOrContradiction:
          "Work pressure is still there; mutual tone made it feel lighter.",
        nextSmallAction: "Propose a weekly 15-minute sync with Sarah",
      }),
    },
    {
      id: "demo-entry-08",
      createdAt: daysAgoIso(7, 20),
      durationSeconds: 44,
      transcript:
        "Mum called — family pressure about the holidays. I said I'd think about it instead of yes-or-no on the spot. Small win. Money is still tight but I'm proud I paused.",
      reflection: reflection({
        mood: "steady",
        emotionalIntensity: 5,
        recurringThemes: ["family", "boundaries", "money"],
        exactLanguagePattern: "think about it instead of yes-or-no",
        concreteObservation:
          "You paused on Mum's holiday ask instead of auto-committing.",
        tensionOrContradiction:
          "Family pressure is present; money is still tight — you chose delay over immediate yes.",
        repeatedSignal: "Money and family expectations intersecting",
        nextSmallAction: "Tell Mum you'll reply by Friday with a clear plan",
      }),
    },
    {
      id: "demo-entry-09",
      createdAt: daysAgoIso(5, 7),
      durationSeconds: 36,
      transcript:
        "Morning felt hopeful — side project progress again. Shipped a tiny feature. Also noticed when I mention money I tense my jaw. Body keeps score even when I'm upbeat.",
      reflection: reflection({
        mood: "hopeful",
        emotionalIntensity: 4,
        recurringThemes: ["creative work", "money", "body awareness"],
        exactLanguagePattern: "when I mention money I tense my jaw",
        concreteObservation:
          "Side-project momentum and money-related jaw tension showed up in the same entry.",
        tensionOrContradiction:
          "Upbeat about shipping; body still clenches when money is named.",
        repeatedSignal: "Jaw tension tied to money mentions",
        nextSmallAction: "Do a 30-second jaw release before checking accounts",
      }),
    },
    {
      id: "demo-entry-10",
      createdAt: daysAgoIso(4, 19),
      durationSeconds: 52,
      transcript:
        "Anxious day — back-to-back meetings and no lunch. Mentioned family pressure in the team retro by accident. People were kind. Still embarrassed. Want to separate work self from home worries more cleanly.",
      reflection: reflection({
        mood: "anxious",
        emotionalIntensity: 7,
        recurringThemes: ["work", "family pressure", "boundaries"],
        exactLanguagePattern: "separate work self from home worries",
        concreteObservation:
          "No lunch on a meeting-heavy day; family pressure leaked into the team retro.",
        tensionOrContradiction:
          "People were kind when home stress surfaced at work — you still felt embarrassed.",
        avoidedOrVagueArea:
          "Family pressure 'by accident' — named the leak, not the specific worry.",
        nextSmallAction: "Block 20 minutes for lunch before the next heavy meeting day",
      }),
    },
    {
      id: "demo-entry-11",
      createdAt: daysAgoIso(2, 8),
      durationSeconds: 41,
      transcript:
        "Calmer weekend. Walked without podcasts. Thought about Sarah project — less dread, more curiosity. Money still on my mind but not loud today.",
      reflection: reflection({
        mood: "calm",
        emotionalIntensity: 3,
        recurringThemes: ["rest", "work reframing"],
        exactLanguagePattern: "less dread, more curiosity",
        concreteObservation:
          "Podcast-free walk shifted the Sarah project from dread to curiosity.",
        tensionOrContradiction:
          "Money still on your mind, but quieter today than earlier in the week.",
        nextSmallAction: "Schedule one walk without input before Monday",
      }),
    },
    {
      id: "demo-entry-12",
      createdAt: daysAgoIso(1, 21),
      durationSeconds: 39,
      transcript:
        "Checked accounts — money worry spiked but I stayed with it. Wrote down three numbers I actually know. Family text can wait until tomorrow. Feeling slightly more in control.",
      reflection: reflection({
        mood: "grounded",
        emotionalIntensity: 5,
        recurringThemes: ["money", "self-regulation"],
        exactLanguagePattern: "wrote down three numbers I actually know",
        concreteObservation:
          "Naming three known numbers cut the money spiral short.",
        tensionOrContradiction:
          "Account check spiked worry; writing numbers brought you back down.",
        avoidedOrVagueArea:
          "Family text 'can wait' — the reply is deferred, not drafted.",
        nextSmallAction: "Update the three-number list after any account check",
      }),
    },
    {
      id: "demo-entry-13",
      createdAt: daysAgoIso(0, 7),
      durationSeconds: 48,
      transcript:
        "Today I'm hopeful about the week. Side project got a kind note from a user. Sarah project has a plan. Still aware of family pressure around the holidays but I'm not carrying it alone in my head anymore.",
      reflection: reflection({
        mood: "hopeful",
        emotionalIntensity: 4,
        recurringThemes: ["momentum", "relationships", "family"],
        exactLanguagePattern: "not carrying it alone in my head anymore",
        concreteObservation:
          "Side-project note, Sarah plan, and holiday pressure are all named out loud.",
        tensionOrContradiction:
          "Holiday decisions are still open — but they're shared, not silent.",
        avoidedOrVagueArea: "",
        nextSmallAction: "Send Sarah the written plan before end of day",
      }),
    },
  ];

  return entries.map((entry) => ({
    ...entry,
    id: entry.id ?? crypto.randomUUID(),
  }));
}

export const DEMO_SEARCH_EXAMPLES = [
  "when did I feel anxious?",
  "times I mentioned money",
  "entries about family pressure",
  "when was I hopeful?",
  "mentions of Sarah",
] as const;

export function isDemoModeActive(): boolean {
  if (!isBrowser()) return false;
  return localStorage.getItem(DEMO_ACTIVE_KEY) === "1";
}

function collectSnapshot(): Record<string, string> {
  const snapshot: Record<string, string> = {};
  if (!isBrowser()) return snapshot;

  for (let i = 0; i < localStorage.length; i += 1) {
    const key = localStorage.key(i);
    if (
      key &&
      key.startsWith("voicememory_") &&
      key !== DEMO_BACKUP_KEY &&
      key !== DEMO_ACTIVE_KEY
    ) {
      const value = localStorage.getItem(key);
      if (value !== null) snapshot[key] = value;
    }
  }
  return snapshot;
}

function clearVoiceMemoryKeys(): void {
  if (!isBrowser()) return;
  const keys: string[] = [];
  for (let i = 0; i < localStorage.length; i += 1) {
    const key = localStorage.key(i);
    if (
      key &&
      key.startsWith("voicememory_") &&
      key !== DEMO_BACKUP_KEY &&
      key !== DEMO_ACTIVE_KEY
    ) {
      keys.push(key);
    }
  }
  for (const key of keys) {
    localStorage.removeItem(key);
  }
}

function restoreSnapshot(snapshot: Record<string, string>): void {
  clearVoiceMemoryKeys();
  for (const [key, value] of Object.entries(snapshot)) {
    localStorage.setItem(key, value);
  }
}

export function enterDemoMode(): void {
  if (!isBrowser()) return;
  if (isDemoModeActive()) return;

  const backup = collectSnapshot();
  localStorage.setItem(DEMO_BACKUP_KEY, JSON.stringify(backup));

  clearVoiceMemoryKeys();

  const entries = buildDemoEntries();
  localStorage.setItem("voicememory_entries", JSON.stringify(entries));
  syncHabitFromEntries();

  const weekEnding = todayKey();
  setCachedWeeklySummary(
    weekEnding,
    "This week mixed work pressure with real wins: Sarah's project moved from dread to curiosity after rest, and you named money worries with concrete numbers instead of spiraling. Family pressure around the holidays is still present, but you're pausing before auto-yes — a pattern of clearer boundaries showing up across entries.",
  );

  localStorage.setItem(DEMO_ACTIVE_KEY, "1");
  trackLaunchEvent(LAUNCH_EVENTS.demoModeEntered);
}

export function exitDemoMode(): boolean {
  if (!isBrowser()) return false;
  if (!isDemoModeActive()) return false;

  const raw = localStorage.getItem(DEMO_BACKUP_KEY);
  localStorage.removeItem(DEMO_ACTIVE_KEY);
  localStorage.removeItem(DEMO_BACKUP_KEY);

  if (raw) {
    try {
      const snapshot = JSON.parse(raw) as Record<string, string>;
      restoreSnapshot(snapshot);
    } catch {
      clearVoiceMemoryKeys();
    }
  } else {
    clearVoiceMemoryKeys();
  }

  trackLaunchEvent(LAUNCH_EVENTS.demoModeExited);
  return true;
}

export function getDemoEntryCount(): number {
  return buildDemoEntries().length;
}
