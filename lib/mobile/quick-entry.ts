import {
  consumeClarityRecordContext,
  peekClarityRecordContext,
} from "@/lib/clarity/clarity-record";
import {
  consumeRecordReturnContext,
  peekRecordReturnContext,
} from "@/lib/reflection/record-return";
import {
  consumeReflexCaptureContext,
  peekReflexCaptureContext,
  storeReflexCaptureContext,
  type ReflexCaptureContext,
} from "@/lib/reflex/reflex-context";
import { detectReflexCapture } from "@/lib/reflex/reflex-capture";
import { trackReflexEvent, REFLEX_EVENTS } from "@/lib/reflex/reflex-observation";

export const QUICK_ENTRY_PATH = "/record";

export type QuickEntryIntent =
  | "home"
  | "record"
  | "return"
  | "reflex"
  | "clarity";

export interface QuickEntryResolution {
  intent: QuickEntryIntent;
  directRecorder: boolean;
  autoStart: boolean;
  reflexContext: ReflexCaptureContext | null;
  preserveQuote: string | null;
  href: string;
}

function isBrowser(): boolean {
  return typeof window !== "undefined";
}

/** Parse URL/hash/search for future deep links — infrastructure only. */
export function parseQuickEntryIntent(
  location?: Pick<Location, "pathname" | "search" | "hash">,
): QuickEntryResolution {
  const empty: QuickEntryResolution = {
    intent: "home",
    directRecorder: false,
    autoStart: false,
    reflexContext: null,
    preserveQuote: null,
    href: "/",
  };

  if (!isBrowser()) return empty;

  const loc = location ?? window.location;
  const params = new URLSearchParams(loc.search);

  if (loc.pathname === QUICK_ENTRY_PATH || params.get("record") === "1") {
    const reflex = detectReflexCapture();
    const ctx =
      peekReflexCaptureContext() ??
      (reflex.continuityLine && reflex.triggerType
        ? {
            continuityLine: reflex.continuityLine,
            triggerType: reflex.triggerType,
            anchorQuote: reflex.anchorQuote,
            noteId: reflex.noteId,
          }
        : null);

    if (ctx && reflex.shouldBypassHomepage) {
      storeReflexCaptureContext(ctx);
    }

    trackReflexEvent(REFLEX_EVENTS.quickEntryOpened, {
      path: loc.pathname,
      intent: params.get("intent") ?? "record",
    });

    return {
      intent: "record",
      directRecorder: true,
      autoStart: params.get("autostart") !== "0",
      reflexContext: ctx,
      preserveQuote: params.get("quote") ?? ctx?.anchorQuote ?? null,
      href: `${QUICK_ENTRY_PATH}${loc.hash === "#recorder" ? "#recorder" : ""}`,
    };
  }

  if (params.get("intent") === "return" || loc.hash === "#recorder") {
    const returnCtx = peekRecordReturnContext();
    const clarity = peekClarityRecordContext();
    return {
      intent: returnCtx ? "return" : clarity ? "clarity" : "record",
      directRecorder: true,
      autoStart: true,
      reflexContext: peekReflexCaptureContext(),
      preserveQuote: returnCtx?.anchorQuote ?? clarity?.anchorSnippet ?? null,
      href: "/#recorder",
    };
  }

  return empty;
}

export function consumeQuickEntryContexts(): {
  recordReturn: ReturnType<typeof consumeRecordReturnContext>;
  clarity: ReturnType<typeof consumeClarityRecordContext>;
  reflex: ReturnType<typeof consumeReflexCaptureContext>;
} {
  return {
    recordReturn: consumeRecordReturnContext(),
    clarity: consumeClarityRecordContext(),
    reflex: consumeReflexCaptureContext(),
  };
}
