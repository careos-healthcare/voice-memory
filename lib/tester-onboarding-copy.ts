/** Calm onboarding copy for real-user validation — no coach, no productivity framing. */

import { ONBOARDING_WELCOME } from "@/lib/onboarding/onboarding-copy";

export const WELCOME_EYEBROW = "VoiceMemory";
export const WELCOME_TITLE = "Welcome";
export const WELCOME_DESCRIPTION = ONBOARDING_WELCOME.description;

export const WELCOME_SECTIONS = [
  {
    title: "Private by default",
    body: "Your reflections stay on this device unless you choose encrypted backup. Nothing is published, scored, or shared without you.",
  },
  {
    title: "Memory grows slowly",
    body: ONBOARDING_WELCOME.memoryGrows,
  },
  {
    title: "You can leave with your words",
    body: "Export your archive anytime from Export or Archive. Your reflections are yours to keep, read elsewhere, or delete.",
  },
  {
    title: "Silence is intentional",
    body: "There is no streak, no nudge to perform, and no pressure to sound a certain way. Pausing is allowed. Coming back later is allowed.",
  },
] as const;

export const HOW_IT_WORKS_EYEBROW = "VoiceMemory";
export const HOW_IT_WORKS_TITLE = "How it works";
export const HOW_IT_WORKS_DESCRIPTION =
  "Short voice reflections, kept locally. Over time, older entries may resurface when they still connect to what you are living now.";

export const HOW_IT_WORKS_SECTIONS = [
  {
    title: "Record when something is worth keeping",
    body: "Speak for a minute or two. Your audio and transcript stay on this device. Analysis runs to organize what you said — not to judge it.",
  },
  {
    title: "Past notes may return",
    body: "As your archive grows, a line from an older reflection may appear again — usually tied to something you said recently. You can open the old entry, bookmark it, or leave it.",
  },
  {
    title: "Revisit when you want",
    body: "Opening an old entry is optional. Some people record a follow-up; some only read. Both are fine.",
  },
  {
    title: "Encrypted backup is optional",
    body: "Sign in if you want an encrypted copy backed up. Without it, everything remains local to this browser.",
  },
  {
    title: "What this is not",
    body: "VoiceMemory is not an AI coach, not therapy, and not a productivity system. It does not diagnose, prescribe, or tell you who to become.",
  },
] as const;

export const PRIVACY_SIMPLE_EYEBROW = "Trust";
export const PRIVACY_SIMPLE_TITLE = "Privacy, simply";
export const PRIVACY_SIMPLE_DESCRIPTION =
  "The short version for testers. Full details live on the Privacy page.";

export const PRIVACY_SIMPLE_SECTIONS = [
  {
    title: "Stays on your device",
    body: "Reflections, transcripts, and audio live in this browser unless you turn on encrypted backup.",
  },
  {
    title: "Processing when you record",
    body: "Audio is sent for transcription and analysis, then discarded from our servers. We do not store your journal as a cloud database.",
  },
  {
    title: "Export anytime",
    body: "Download your archive as JSON or readable Markdown whenever you want.",
  },
  {
    title: "Delete anytime",
    body: "Remove individual entries or wipe all local data from Settings.",
  },
  {
    title: "Optional backup",
    body: "Encrypted sync is your choice. Without it, nothing leaves this device except what you explicitly export.",
  },
] as const;

export const TESTER_ONBOARDING_LINKS = [
  { href: "/how-it-works", label: "How it works" },
  { href: "/privacy-simple", label: "Privacy, simply" },
  { href: "/privacy", label: "Full privacy" },
  { href: "/safety", label: "Safety" },
  { href: "/memory", label: "Start reflecting" },
] as const;
