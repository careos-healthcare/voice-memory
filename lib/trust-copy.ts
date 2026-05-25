/** Production trust, safety, and legal copy — user-facing only. */

export const CONTACT_EMAIL = "hello@voicememory.app";

export const PRIVATE_BY_DEFAULT_LINE =
  "Local-first and private by default. Your reflections stay on this device unless you choose encrypted backup.";

export const NOT_THERAPY_LINE =
  "VoiceMemory is a reflective mirror for your own voice reflections. It is not therapy, counseling, medical advice, or a diagnosis.";

export const CRISIS_DISCLAIMER =
  "VoiceMemory cannot help in an emergency. If you or someone else may be in immediate danger, contact local emergency services. In the UK, Samaritans are available 24/7 on 116 123. In the US, call or text 988 for the Suicide & Crisis Lifeline.";

export const LOCAL_FIRST_SUMMARY =
  "Your reflections, transcripts, mood notes, and memory patterns are stored in this browser (localStorage and IndexedDB for audio). VoiceMemory does not operate a cloud journal database for your entries.";

export const OPENAI_PROCESSING_SUMMARY =
  "When you record, your audio is sent to our server and transcribed with OpenAI Whisper. The transcript is analyzed with OpenAI to produce structured reflection fields. We do not use your reflections to train OpenAI models. Audio is not retained on our servers after transcription completes.";

export const ENCRYPTED_SYNC_SUMMARY =
  "If you sign in, your archive is encrypted on this device before backup. Our servers store ciphertext only — not raw transcripts, audio, or reflection text. Sync is optional.";

export const DATA_EXPORT_SUMMARY =
  "You can export your data anytime from Export, Archive, or Settings: full JSON archive, readable Markdown, and (on Pro) printable reports. Exports are generated on your device from local storage.";

export const DATA_DELETION_SUMMARY =
  "Delete individual reflections from each entry page, or delete all local data from Settings. Deletion removes journal entries, audio, and preferences on this device. Server-side transcription requests are not stored as a permanent journal.";

export const DELETE_ALL_CONFIRM_PHRASE = "DELETE";

export const DELETE_ALL_LOCAL_PROMPT =
  "Delete ALL local VoiceMemory data on this device? This removes reflections, audio, bookmarks, preferences, and goals. This cannot be undone.";

export const DELETE_ACCOUNT_PLACEHOLDER =
  "Full account deletion from our servers is not available yet. Sign out to stop syncing. Delete all local data in Settings to remove everything on this device. Email hello@voicememory.app if you need help removing encrypted backup data.";

export const TRUST_FOOTER_LINKS = [
  { href: "/privacy", label: "Privacy" },
  { href: "/terms", label: "Terms" },
  { href: "/safety", label: "Safety" },
  { href: "/contact", label: "Contact" },
  { href: "/settings", label: "Settings" },
] as const;

export const PRIVACY_TRUST_POINTS = [
  {
    title: "What stays local",
    body: "Reflections, transcripts, audio recordings, bookmarks, reminder preferences, goals, and memory notes live in this browser unless you export or enable encrypted backup.",
  },
  {
    title: "What is sent for transcription",
    body: "When you record, audio is sent to our server for Whisper transcription, then discarded. It is not kept as a permanent cloud recording.",
  },
  {
    title: "What is sent for reflection",
    body: "Your transcript text is sent for structured reflection fields during analysis. That text is not stored on our servers as a journal — only processed to return results to your device.",
  },
  {
    title: "What is encrypted before sync",
    body: ENCRYPTED_SYNC_SUMMARY,
  },
  {
    title: "How deletion works",
    body: DATA_DELETION_SUMMARY,
  },
] as const;

export const PRIVACY_SECTIONS = [
  {
    title: "Private by default",
    body: PRIVATE_BY_DEFAULT_LINE,
  },
  {
    title: "What we collect",
    body: "On your device: voice reflections, transcripts, reflection fields, optional reminder preferences, reflection goals, and optional Pro preview state. On our servers (transient): audio during transcription and transcript text during analysis — not kept as a permanent account journal.",
  },
  {
    title: "Local-first storage",
    body: LOCAL_FIRST_SUMMARY,
  },
  {
    title: "OpenAI processing",
    body: OPENAI_PROCESSING_SUMMARY,
  },
  {
    title: "Encrypted backup (optional)",
    body: ENCRYPTED_SYNC_SUMMARY,
  },
  {
    title: "What we do not do",
    body: "We do not sell your reflections. We do not provide therapy or clinical diagnosis. We do not use guilt, streaks, or pressure to keep you recording. AI summaries describe patterns in what you said — they are not complete or authoritative.",
  },
  {
    title: "Export your data",
    body: DATA_EXPORT_SUMMARY,
  },
  {
    title: "Delete your data",
    body: DATA_DELETION_SUMMARY,
  },
  {
    title: "Contact",
    body: `Questions about privacy: ${CONTACT_EMAIL}`,
  },
] as const;

export const TERMS_SECTIONS = [
  {
    title: "Service description",
    body: "VoiceMemory is private memory intelligence for voice reflections — a reflective mirror, not therapy or a diagnosis. The product is provided as-is for personal self-reflection.",
  },
  {
    title: "Not medical or therapeutic advice",
    body: NOT_THERAPY_LINE,
  },
  {
    title: "Your content",
    body: "You retain ownership of what you record. You are responsible for what you choose to speak, export, or share outside the app.",
  },
  {
    title: "Acceptable use",
    body: "Do not use VoiceMemory to store illegal content or to harass others. Do not attempt to reverse-engineer or abuse API endpoints.",
  },
  {
    title: "Subscriptions",
    body: "Pro features may be offered via subscription when billing launches. Free tier limits (such as the last 7 visible entries) may change with notice on the pricing page.",
  },
  {
    title: "Limitation of liability",
    body: "VoiceMemory is a software tool, not a crisis service. We are not liable for decisions you make based on AI-generated summaries. See the Safety page for crisis resources.",
  },
] as const;

export const EMOTIONAL_SAFETY_SECTIONS = [
  {
    title: "Not crisis support",
    body: "VoiceMemory cannot monitor your safety or respond to emergencies. It does not have human moderators or clinicians on call.",
  },
  {
    title: "Not therapy",
    body: NOT_THERAPY_LINE,
  },
  {
    title: "You control your archive",
    body: "Export, restore, or delete your reflections anytime from Archive and Settings. Nothing requires you to keep recording or stay active.",
  },
  {
    title: "Silence is respected",
    body: "There is no streak to maintain, no penalty for pausing, and reminders are off by default. Return when you want — your past words wait quietly.",
  },
  {
    title: "Listening mode",
    body: "Save voice without immediate interpretation. Your transcript and audio are kept — reflect later when it feels right.",
  },
] as const;

export const SAFETY_SECTIONS = [
  {
    title: "Reflective mirror only",
    body: NOT_THERAPY_LINE,
  },
  {
    title: "No diagnosis",
    body: "AI outputs may label moods or themes in plain language. That is not a mental health diagnosis, risk assessment, or treatment plan.",
  },
  ...EMOTIONAL_SAFETY_SECTIONS,
  {
    title: "If you need urgent help",
    body: CRISIS_DISCLAIMER,
  },
  {
    title: "Sharing outside the app",
    body: "Share memory cards and exports only if you are comfortable. Transcript excerpts are off by default when copying share cards.",
  },
  {
    title: "Local-first privacy",
    body: LOCAL_FIRST_SUMMARY,
  },
  {
    title: "Cloud processing",
    body: OPENAI_PROCESSING_SUMMARY,
  },
] as const;
