"use client";

import { useEffect, useRef, useState } from "react";
import { usePathname } from "next/navigation";

import { ReturnReasonPrompt } from "@/components/retention/ReturnReasonPrompt";
import { SessionOutcomePrompt } from "@/components/retention/SessionOutcomePrompt";
import { observeFirstValueMoment } from "@/lib/retention/first-value-moments";
import {
  shouldAskReturnReasonThisSession,
} from "@/lib/retention/return-reason-survey";
import { markAppSessionStarted } from "@/lib/retention/session-retention";
import { shouldAskSessionOutcome } from "@/lib/retention/session-outcome";

const OUTCOME_DELAY_MS = 90_000;

function isInternalRoute(pathname: string): boolean {
  return pathname.startsWith("/internal");
}

export function RetentionInstrumentation() {
  const pathname = usePathname();
  const [sessionNumber, setSessionNumber] = useState(0);
  const [showReturnReason, setShowReturnReason] = useState(false);
  const [showOutcome, setShowOutcome] = useState(false);
  const outcomeTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const returnReasonDoneRef = useRef(false);
  const sessionRef = useRef(0);

  useEffect(() => {
    if (isInternalRoute(pathname)) return;

    const n = markAppSessionStarted();
    sessionRef.current = n;
    setSessionNumber(n);
    if (n >= 2) {
      observeFirstValueMoment("second_session_reached");
    }
    if (shouldAskReturnReasonThisSession(n)) {
      setShowReturnReason(true);
    } else {
      returnReasonDoneRef.current = true;
    }
  }, [pathname]);

  const scheduleOutcomePrompt = () => {
    if (outcomeTimerRef.current) clearTimeout(outcomeTimerRef.current);
    const n = sessionRef.current;
    if (!shouldAskSessionOutcome(n)) return;
    outcomeTimerRef.current = setTimeout(() => {
      if (shouldAskSessionOutcome(sessionRef.current)) {
        setShowOutcome(true);
      }
    }, OUTCOME_DELAY_MS);
  };

  const onReturnReasonDone = () => {
    setShowReturnReason(false);
    returnReasonDoneRef.current = true;
    scheduleOutcomePrompt();
  };

  useEffect(() => {
    if (isInternalRoute(pathname)) return;
    if (sessionNumber > 0 && returnReasonDoneRef.current && !showReturnReason) {
      scheduleOutcomePrompt();
    }
    return () => {
      if (outcomeTimerRef.current) clearTimeout(outcomeTimerRef.current);
    };
  }, [pathname, sessionNumber, showReturnReason]);

  useEffect(() => {
    const onHide = () => {
      if (document.visibilityState !== "hidden") return;
      if (isInternalRoute(pathname)) return;
      if (!shouldAskSessionOutcome(sessionNumber)) return;
      if (showOutcome || showReturnReason) return;
      if (returnReasonDoneRef.current || sessionNumber > 0) {
        setShowOutcome(true);
      }
    };
    document.addEventListener("visibilitychange", onHide);
    return () => document.removeEventListener("visibilitychange", onHide);
  }, [pathname, sessionNumber, showOutcome, showReturnReason]);

  if (isInternalRoute(pathname) || sessionNumber === 0) return null;

  return (
    <>
      {showReturnReason ? (
        <ReturnReasonPrompt sessionNumber={sessionNumber} onDone={onReturnReasonDone} />
      ) : null}
      {showOutcome && !showReturnReason ? (
        <SessionOutcomePrompt
          sessionNumber={sessionNumber}
          onDone={() => setShowOutcome(false)}
        />
      ) : null}
    </>
  );
}
