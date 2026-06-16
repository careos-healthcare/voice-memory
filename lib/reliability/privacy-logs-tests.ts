import { logServerEvent } from "../server/structured-log";

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

  return { failures };
}
