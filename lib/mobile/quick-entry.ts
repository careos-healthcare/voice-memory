import {
  buildClarityRecordContext,
  consumeClarityRecordContext,
  peekClarityRecordContext,
  storeClarityRecordContext,
} from "@/lib/clarity/clarity-record";
import {
  buildDirectRecordHref,
  type DirectRecordSource,
} from "@/lib/capture/direct-record";
import {
  buildRecordReturnFromOpenLoop,
  consumeRecordReturnContext,
  peekRecordReturnContext,
  storeRecordReturnContext,
} from "@/lib/reflection/record-return";
import {
  consumeReflexCaptureContext,
  peekReflexCaptureContext,
  storeReflexCaptureContext,
  type ReflexCaptureContext,
} from "@/lib/reflex/reflex-context";
import { detectReflexCapture } from "@/lib/reflex/reflex-capture";
import { trackReflexEvent, REFLEX_EVENTS } from "@/lib/reflex/reflex-observation";
import type { RecordReturnContext } from "@/types/record-return";

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
  recordReturn: RecordReturnContext | null;
  preserveQuote: string | null;
  source: DirectRecordSource | null;
  entryId: string | null;
  loopId: string | null;
  href: string;
}

function isBrowser(): boolean {
  return typeof window !== "undefined";
}

function mapSourceParam(raw: string | null): DirectRecordSource | null {
  if (
    raw === "resurfacing" ||
    raw === "open_loop" ||
    raw === "clarity" ||
    raw === "return" ||
    raw === "reflex"
  ) {
    return raw;
  }
  return null;
}

function buildReturnFromParams(
  source: DirectRecordSource | null,
  params: URLSearchParams,
): RecordReturnContext | null {
  const quote = params.get("quote")?.trim();
  const loopId = params.get("loopId");
  const entryId = params.get("entryId");

  if (source === "open_loop" && loopId && quote) {
    return buildRecordReturnFromOpenLoop({
      openLoopId: loopId,
      anchorQuote: quote,
      sourceEntryId: entryId ?? "",
    });
  }

  if (quote && (source === "resurfacing" || source === "return")) {
    return {
      id: `return-${source}-${loopId ?? entryId ?? "quick"}`,
      anchorQuote: quote.slice(0, 220),
      noteId: loopId ?? entryId ?? `quick-${source}`,
      source: source === "resurfacing" ? "resurfacing" : "primary_callback",
      openLoopId: loopId ?? undefined,
      pastEntryId: entryId ?? undefined,
    };
  }

  return peekRecordReturnContext();
}

/** Parse URL for direct capture — `/record` is first-class. */
export function parseQuickEntryIntent(
  location?: Pick<Location, "pathname" | "search" | "hash">,
): QuickEntryResolution {
  const empty: QuickEntryResolution = {
    intent: "home",
    directRecorder: false,
    autoStart: false,
    reflexContext: null,
    recordReturn: null,
    preserveQuote: null,
    source: null,
    entryId: null,
    loopId: null,
    href: "/",
  };

  if (!isBrowser()) return empty;

  const loc = location ?? window.location;
  const params = new URLSearchParams(loc.search);
  const source = mapSourceParam(params.get("source"));

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

    const recordReturn = buildReturnFromParams(source, params);
    if (recordReturn) storeRecordReturnContext(recordReturn);

    if (source === "clarity" && params.get("entryId") && !peekClarityRecordContext()) {
      storeClarityRecordContext(
        buildClarityRecordContext({
          entryId: params.get("entryId")!,
          anchorSnippet: params.get("quote") ?? "",
        }),
      );
    }

    trackReflexEvent(REFLEX_EVENTS.quickEntryOpened, {
      path: loc.pathname,
      source: source ?? "record",
    });

    const href = buildDirectRecordHref({
      source: source ?? "return",
      quote: params.get("quote") ?? undefined,
      loopId: params.get("loopId") ?? undefined,
      entryId: params.get("entryId") ?? undefined,
      autostart: params.get("autostart") !== "0",
    });

    return {
      intent: "record",
      directRecorder: true,
      autoStart: params.get("autostart") !== "0",
      reflexContext: ctx,
      recordReturn,
      preserveQuote: params.get("quote") ?? ctx?.anchorQuote ?? recordReturn?.anchorQuote ?? null,
      source,
      entryId: params.get("entryId"),
      loopId: params.get("loopId"),
      href,
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
      recordReturn: returnCtx,
      preserveQuote: returnCtx?.anchorQuote ?? clarity?.anchorSnippet ?? null,
      source: returnCtx ? "return" : clarity ? "clarity" : null,
      entryId: null,
      loopId: null,
      href: buildDirectRecordHref({ source: "return", autostart: true }),
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

export { buildDirectRecordHref, openDirectToRecordingHref } from "@/lib/capture/direct-record";
