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

function reflection(partial: Partial<Reflection> & Pick<Reflection, "mood" | "emotionalIntensity">): Reflection {
  return {
    mood: partial.mood,
    emotionalIntensity: partial.emotionalIntensity,
    recurringThemes: partial.recurringThemes ?? [],
    hiddenConcern: partial.hiddenConcern ?? "",
    positiveSignal: partial.positiveSignal ?? "",
    recommendation: partial.recommendation ?? "",
    exactLanguagePattern: partial.exactLanguagePattern,
    concreteObservation: partial.concreteObservation,
    repeatedSignal: partial.repeatedSignal,
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
        hiddenConcern: "Fear of falling behind on the Sarah project",
        positiveSignal: "Finished one difficult task before lunch despite stress",
        recommendation: "Block 25 minutes tomorrow morning for the timeline review only",
        exactLanguagePattern: "my chest tighten when deadlines stack up",
        concreteObservation: "Sarah's call triggered a physical stress response tied to project timing",
        repeatedSignal: "Deadline stacking as an anxiety trigger",
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
        hiddenConcern: "Tension between wanting to see family and financial limits",
        positiveSignal: "Named the money worry out loud instead of avoiding it",
        recommendation: "Sketch a simple visit budget before replying to Mum",
        exactLanguagePattern: "that familiar squeeze after rent",
        concreteObservation: "Family visit desire conflicts with post-rent account balance",
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
        hiddenConcern: "Perfectionism slowing down shipping",
        positiveSignal: "Connected good sleep to clearer optimism about the side project",
        recommendation: "Define the smallest shippable slice of the side project",
        exactLanguagePattern: "don't need perfection, just something real",
        concreteObservation: "Hope followed rest — energy shifted after sleeping well",
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
        hiddenConcern: "Repeating career conversations with Dad without progress",
        positiveSignal: "Stayed calm at dinner despite internal tension",
        recommendation: "Prepare one sentence for redirecting the career topic",
        exactLanguagePattern: "that old knot in my stomach",
        concreteObservation: "Dad's career questions still land physically even when you respond calmly",
        repeatedSignal: "Family pressure around career direction",
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
        hiddenConcern: "Anticipatory anxiety before meetings",
        positiveSignal: "Standup went fine — evidence against the judgment story",
        recommendation: "Keep a one-line 'what actually happened' log after anxious meetings",
        exactLanguagePattern: "imagining everyone judging the update",
        concreteObservation: "Pre-meeting anxiety did not match post-meeting outcome",
        repeatedSignal: "Judgment anticipation before standups",
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
        hiddenConcern: "Career move impact on mortgage and stability",
        positiveSignal: "Conversation with Alex clarified need for concrete numbers",
        recommendation: "List financial constraints before exploring team changes",
        exactLanguagePattern: "need numbers before any decision",
        concreteObservation: "Social conversation surfaced mortgage as a decision gate",
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
        hiddenConcern: "Carrying project stress solo",
        positiveSignal: "Sarah's appreciative check-in reduced isolation",
        recommendation: "Ask for one explicit collaboration touchpoint per week",
        exactLanguagePattern: "breathe easier when collaboration feels mutual",
        concreteObservation: "Mutual tone from Sarah shifted physical tension downward",
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
        hiddenConcern: "Holiday expectations vs budget",
        positiveSignal: "Paused instead of auto-yes to Mum's holiday ask",
        recommendation: "Reply with a timeline for a decision, not immediate commitment",
        exactLanguagePattern: "think about it instead of yes-or-no",
        concreteObservation: "Chose pause over automatic agreement on family holiday plans",
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
        hiddenConcern: "Physical tension when money topics arise",
        positiveSignal: "Shipped a tiny side-project feature",
        recommendation: "Notice jaw tension the next time money comes up in conversation",
        exactLanguagePattern: "when I mention money I tense my jaw",
        concreteObservation: "Positive creative momentum coexists with money-related body tension",
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
        hiddenConcern: "Home stress bleeding into work conversations",
        positiveSignal: "Team responded with kindness when family pressure surfaced",
        recommendation: "Take lunch away from desk on heavy meeting days",
        exactLanguagePattern: "separate work self from home worries",
        concreteObservation: "Skipped lunch on a meeting-heavy day and family stress leaked into work",
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
        hiddenConcern: "Whether calm is temporary without structural change",
        positiveSignal: "Sarah project felt curious instead of dreadful after rest",
        recommendation: "Protect one podcast-free walk this week",
        exactLanguagePattern: "less dread, more curiosity",
        concreteObservation: "Rest shifted Sarah project from dread to curiosity",
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
        hiddenConcern: "Avoidance of concrete financial numbers",
        positiveSignal: "Named three known numbers instead of spiraling",
        recommendation: "Keep a short list of 'numbers I know' visible this week",
        exactLanguagePattern: "wrote down three numbers I actually know",
        concreteObservation: "Concrete numbers reduced money spiral intensity",
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
        hiddenConcern: "Holiday decisions still unresolved",
        positiveSignal: "External validation on side project plus clearer Sarah plan",
        recommendation: "Capture what's working this week before it fades",
        exactLanguagePattern: "not carrying it alone in my head anymore",
        concreteObservation: "Multiple threads feel named and shared rather than silent",
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
