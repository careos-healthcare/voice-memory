import { buildMobileJourneyAudit } from "@/lib/mobile/mobile-journey-audit";
import { buildMobilePaywallAudit } from "@/lib/mobile/mobile-paywall-audit";
import { readFlutter, flutterHasRoute } from "@/lib/mobile/flutter-repo";
import type { ArchiveReviewAnswer, MobileArchiveReview } from "@/types/mobile-first-class";

const QUESTIONS: { id: ArchiveReviewAnswer["id"]; question: string }[] = [
  { id: "understand_archive", question: "Can user understand archive?" },
  { id: "see_belief", question: "Can user see belief?" },
  { id: "see_trust", question: "Can user see trust?" },
  { id: "see_change", question: "Can user see change?" },
  { id: "protect_archive", question: "Can user protect archive?" },
  { id: "subscribe", question: "Can user subscribe?" },
  { id: "restore", question: "Can user restore?" },
];

/** Archive-first mobile review — static answers from routes and widgets. */
export function buildMobileArchiveReview(): MobileArchiveReview {
  const journey = buildMobileJourneyAudit();
  const paywall = buildMobilePaywallAudit();
  const archive = readFlutter("lib/screens/archive_belief_screen.dart");

  const byStep = (id: string) => journey.steps.find((s) => s.id === id);

  const answers: ArchiveReviewAnswer[] = QUESTIONS.map((q) => {
    switch (q.id) {
      case "understand_archive":
        return {
          ...q,
          answerableOnMobile:
            archive.includes("ArchiveBeliefScreen") &&
            archive.includes("ArchiveProgressBarMobile"),
          evidence: ["/archive-belief with progress + belief header"],
        };
      case "see_belief":
        return {
          ...q,
          answerableOnMobile: archive.includes("ArchiveBeliefHeaderMobile"),
          evidence: ["ArchiveBeliefHeaderMobile"],
        };
      case "see_trust":
        return {
          ...q,
          answerableOnMobile: archive.includes("ArchiveReputationCardMobile"),
          evidence: ["ArchiveReputationCardMobile on archive home"],
        };
      case "see_change":
        return {
          ...q,
          answerableOnMobile:
            (byStep("archive_changes")?.reachableOnMobile ?? false) &&
            archive.includes("ArchiveStateDeltaCardMobile"),
          evidence: ["/discover tab", "ArchiveStateDeltaCardMobile"],
        };
      case "protect_archive":
        return {
          ...q,
          answerableOnMobile: byStep("protect_archive")?.reachableOnMobile ?? false,
          evidence: ["ProtectArchiveBanner + account auth"],
        };
      case "subscribe":
        return {
          ...q,
          answerableOnMobile:
            flutterHasRoute("/pricing") && (byStep("purchase")?.reachableOnMobile ?? false),
          evidence: ["/pricing — may open browser for Stripe"],
        };
      case "restore":
        return {
          ...q,
          answerableOnMobile:
            paywall.checks.find((c) => c.id === "restore_purchases")?.passed === true,
          evidence: paywall.checks.find((c) => c.id === "restore_purchases")?.note
            ? [paywall.checks.find((c) => c.id === "restore_purchases")!.note]
            : [],
        };
      default:
        return { ...q, answerableOnMobile: false, evidence: [] };
    }
  });

  return {
    generatedAt: new Date().toISOString(),
    questions: answers,
    allFromMobile: answers.every((a) => a.answerableOnMobile),
  };
}
