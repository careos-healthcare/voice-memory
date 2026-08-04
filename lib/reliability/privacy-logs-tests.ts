import { logServerEvent } from "../server/structured-log";
import {
  EPHEMERAL_AI_HEADERS,
  logEphemeralAiFailure,
} from "../privacy/ephemeral-ai-response";

export function runPrivacyLogsTests(): { failures: string[] } {
  const failures: string[] = [];
  let captured = "";

  const original = console.info;
  console.info = (...args: unknown[]) => {
    captured = args.map(String).join(" ");
  };

  try {
    logServerEvent("health_check", {
      transcript: "must-not-appear",
      journal_body: "hidden",
      ok: true,
      route: "/api/test",
    });
    const json = captured.replace(/^\[ArchiveMe\]\s*/, "").trim();
    const payload = JSON.parse(json) as Record<string, unknown>;
    for (const key of ["transcript", "journal_body"]) {
      if (key in payload) {
        failures.push(`structured log leaked banned field: ${key}`);
      }
    }
    if (payload.ok !== true || payload.route !== "/api/test") {
      failures.push("structured log dropped allowed fields");
    }
  } catch (e) {
    failures.push(`privacy-logs runtime test threw: ${e}`);
  } finally {
    console.info = original;
  }

  const originalError = console.error;
  let errorCaptured = "";
  console.error = (...args: unknown[]) => {
    errorCaptured = JSON.stringify(args);
  };
  try {
    logEphemeralAiFailure(
      "dashboard-synthesis",
      new Error("must-not-log-private-transcript"),
    );
    if (errorCaptured.includes("must-not-log-private-transcript")) {
      failures.push("ephemeral AI error logging leaked private content");
    }
    if (!EPHEMERAL_AI_HEADERS["Cache-Control"].includes("no-store")) {
      failures.push("ephemeral AI responses are not explicitly no-store");
    }
  } catch (e) {
    failures.push(`ephemeral privacy test threw: ${e}`);
  } finally {
    console.error = originalError;
  }

  return { failures };
}
