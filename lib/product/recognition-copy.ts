/** Short recognition-first copy — almost disappears, reads in under two seconds. */

export const RECOGNITION_COPY = {
  appSubtitle: "Your words, kept privately.",
  appTagline: "See the patterns you keep missing.",
  appLead:
    "One recording is a moment. ArchiveMe shows what keeps repeating across your life.",
  wedge: "You said this before.",
  notAiJournal: "Your words stay yours — private, on this device.",
  homepageSpeak: "Record short reflections on this device",
  homepageRemember: "Your archive compares weeks and months — not one chat reply",
  homepageReturn: "Blind spots and Discover show what changed since your last visit",
  homepageCta: "Say it in your voice. Repetition across time is what this tracks.",
  firstSave:
    "Saved. Say one more later — ArchiveMe can start noticing what comes back.",
  nothingReturned: "Nothing has returned yet. Keep speaking naturally.",
  journalLead: "What came back, then what you said.",
  memoryTitle: "What returned",
} as const;

/** Banned in user-facing surfaces — product/system voice. */
export const BANNED_PRODUCT_VOICE = [
  "voice notes",
  "voice note app",
  "memory resurfacing",
  "continuity intelligence",
  "archive resonance",
  "intelligence engine",
  "validator",
  "validators",
  "architecture",
  "archiveme brings back phrases",
  "ai summary",
  "ai-generated",
  "speaker expresses",
  "pattern analysis",
  "insight engine",
] as const;
