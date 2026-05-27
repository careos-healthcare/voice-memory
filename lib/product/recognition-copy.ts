/** Short recognition-first copy — almost disappears, reads in under two seconds. */

export const RECOGNITION_COPY = {
  appSubtitle: "Your words, kept privately.",
  appTagline: "What you said can come back.",
  appLead: "Speak aloud. When it matches something you said before, it returns.",
  wedge: "You said this before.",
  notAiJournal: "Your words stay yours — private, on this device.",
  homepageSpeak: "Speak aloud",
  homepageRemember: "Your words stay here",
  homepageReturn: "What repeats can come back",
  homepageCta:
    "Say it in your voice. When you repeat yourself across days, you may see it again.",
  firstSave:
    "Saved. Say one more later — VoiceMemory can start noticing what comes back.",
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
  "voicememory brings back phrases",
  "ai summary",
  "ai-generated",
  "speaker expresses",
  "pattern analysis",
  "insight engine",
] as const;
