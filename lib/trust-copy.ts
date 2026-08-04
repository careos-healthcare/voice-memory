/** Production trust, safety, and legal copy — user-facing only. */

import { SERVICE_DESCRIPTION } from "@/lib/product-copy";

export const CONTACT_EMAIL = "hello@voicememory.app";

export const PRIVATE_BY_DEFAULT_LINE =
  "Local-first and private by default. Your reflections stay on this device unless you choose encrypted backup.";

export const NOT_THERAPY_LINE =
  "ArchiveMe resurfaces your own voice reflections. It is not therapy, counseling, medical advice, or a diagnosis.";

export const CRISIS_DISCLAIMER =
  "ArchiveMe cannot help in an emergency. If you or someone else may be in immediate danger, contact local emergency services. In the UK, Samaritans are available 24/7 on 116 123. In the US, call or text 988 for the Suicide & Crisis Lifeline.";

export const LOCAL_FIRST_SUMMARY =
  "Your reflections, transcripts, mood notes, and memory patterns are stored in this browser (localStorage and IndexedDB for audio). ArchiveMe does not operate a cloud journal database for your entries.";

export const AI_TRANSCRIPTION_ANALYSIS_SUMMARY =
  "When you record, ArchiveMe may send audio or transcript text to the app backend so it can transcribe and organize what you said. The result is returned to your archive.";

export const PROCESSING_PROVIDERS_SUMMARY =
  "ArchiveMe may use trusted processing providers for transcription, analysis, account, billing, or crash diagnostics. Provider names may appear in the full privacy policy where required.";

export const ENCRYPTED_SYNC_SUMMARY =
  "If you sign in, your archive is encrypted on this device before backup. Our servers store ciphertext only — not raw transcripts, audio, or reflection text. Sync is optional.";

export const DATA_EXPORT_SUMMARY =
  "You can export your data anytime from Export, Archive, or Settings: full JSON archive, readable Markdown, and printable reports. Exports are generated on your device from local storage.";

export const DATA_DELETION_SUMMARY =
  "Delete individual reflections from each entry page, or delete all local data from Settings. Deletion removes journal entries, audio, and preferences on this device. Server-side transcription requests are not stored as a permanent journal.";

export const DELETE_ALL_CONFIRM_PHRASE = "DELETE";

export const DELETE_ALL_LOCAL_PROMPT =
  "Delete ALL local ArchiveMe data on this device? This removes reflections, audio, bookmarks, preferences, and goals. This cannot be undone.";

export const DELETE_ACCOUNT_LEAD =
  "Removes encrypted backup blobs and sessions from our servers. Your journal on this device is not deleted until you clear local data in Settings.";

export const DELETE_ACCOUNT_CONFIRM_PHRASE = "DELETE MY ACCOUNT";

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
    body: "When you record, audio or transcript text may be sent to the app backend for transcription and analysis. Processing is limited to returning results to your archive.",
  },
  {
    title: "What is sent for reflection",
    body: "Transcript text may be sent for structured reflection fields during analysis. That text is not stored on our servers as a journal — only processed to return results to your device.",
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
    title: "What stays on your device",
    body: "Your archive entries, saved details, action items, surfacing choices, memory controls, packs, pins, and collections are stored locally by default.",
  },
  {
    title: "Local-first storage",
    body: LOCAL_FIRST_SUMMARY,
  },
  {
    title: "AI transcription and analysis",
    body: AI_TRANSCRIPTION_ANALYSIS_SUMMARY,
  },
  {
    title: "Optional encrypted backup",
    body: ENCRYPTED_SYNC_SUMMARY,
  },
  {
    title: "What ArchiveMe does not do",
    body: "ArchiveMe does not sell your reflections. ArchiveMe does not include recording text in analytics. ArchiveMe does not turn every entry into personal memory by default.",
  },
  {
    title: "Your controls",
    body: "You can mark entries as Hypothetical, Not about me, Sensitive, Do not surface, Preserve original, Keep separate, or Treat as new.",
  },
  {
    title: "Processing providers",
    body: PROCESSING_PROVIDERS_SUMMARY,
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
    body: `${SERVICE_DESCRIPTION} The product is provided as-is for recording your own reflections.`,
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
    body: "Do not use ArchiveMe to store illegal content or to harass others. Do not attempt to reverse-engineer or abuse API endpoints.",
  },
  {
    title: "Subscriptions",
    body: "Your original recordings, entries, transcripts, and exports remain accessible without Pro. A subscription may unlock new ongoing comparisons, deeper archive analysis, and configured remote processing.",
  },
  {
    title: "Limitation of liability",
    body: "ArchiveMe is a software tool, not a crisis service. We are not liable for decisions you make based on summaries generated from your transcript. See the Safety page for crisis resources.",
  },
] as const;

export const EMOTIONAL_SAFETY_SECTIONS = [
  {
    title: "Not crisis support",
    body: "ArchiveMe cannot monitor your safety or respond to emergencies. It does not have human moderators or clinicians on call.",
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
    title: "Your own voice only",
    body: NOT_THERAPY_LINE,
  },
  {
    title: "No diagnosis",
    body: "Automated outputs may label moods or themes in plain language. That is not a diagnosis, risk assessment, or treatment plan.",
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
    body: AI_TRANSCRIPTION_ANALYSIS_SUMMARY,
  },
] as const;
