"use client";

import {
  AUTH_VALUE_MANUAL_SCENARIOS,
  AUTH_VALUE_ROADMAP_FREEZE,
  buildAuthValueValidationReport,
} from "@/lib/auth/auth-value-validation";
import type { AuthValueValidationReport } from "@/types/auth-value-validation";

interface AuthValueValidationPanelProps {
  report: AuthValueValidationReport;
}

function verdictClass(verdict: string): string {
  if (verdict === "strong") return "text-emerald-400";
  if (verdict === "weak") return "text-amber-400";
  return "text-zinc-400";
}

function formatRate(rate: number | null): string {
  if (rate === null) return "—";
  return `${rate}%`;
}

export function AuthValueValidationPanel({ report }: AuthValueValidationPanelProps) {
  return (
    <section className="space-y-8">
      <div className="rounded-2xl border border-amber-500/30 bg-amber-950/15 px-5 py-4">
        <p className="text-xs uppercase tracking-[0.18em] text-amber-200/90">Evidence phase</p>
        <p className="mt-2 text-sm leading-relaxed text-zinc-300">
          Do not expand auth. Run 5–10 people through Protect Archive (scenario #2) and write
          exact quotes. Ignore funnel rates here until 10+ real users — one browser is noise.
        </p>
        <p className="mt-2 text-sm text-zinc-400">
          Key interview: &ldquo;If your archive disappeared tomorrow, would you care?&rdquo; Weak
          answer → improve archive value, not auth.
        </p>
        <p className="mt-3 font-mono text-xs text-zinc-600">
          docs/AUTH_VALIDATION_EVIDENCE.md · docs/templates/auth-scenario-2-quote-log.md
        </p>
      </div>

      <div className="rounded-2xl border border-violet-500/25 bg-violet-950/10 p-6">
        <p className="text-xs uppercase tracking-[0.18em] text-violet-300/80">Auth value validation</p>
        <h2 className="mt-2 text-lg font-semibold text-white">{report.mainQuestion}</h2>
        <p className={`mt-3 text-sm leading-relaxed ${verdictClass(report.verdict)}`}>
          {report.verdictAnswer}
        </p>
        <p className="mt-2 text-xs text-zinc-500">Verdict: {report.verdict}</p>
      </div>

      <dl className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
        <Metric label="Guest mode started" value={report.guestModeStarted} />
        <Metric label="Protect banner seen" value={report.protectArchiveBannerSeen} />
        <Metric label="Protect archive clicked" value={report.protectArchiveClicked} />
        <Metric
          label="Protect Archive conversion"
          value={formatRate(report.protectArchiveConversionRate)}
          highlight
        />
        <Metric label="Auth prompts shown" value={report.authPromptsShown} />
        <Metric label="Auth verified" value={report.authVerified} />
        <Metric
          label="Overall prompt → verified"
          value={formatRate(report.overallPromptToVerifiedRate)}
        />
        <Metric
          label="Paywall prompt → verified"
          value={formatRate(report.paywallPromptToVerifiedRate)}
        />
      </dl>

      <p className="text-xs text-zinc-500">
        Protect Archive conversion = auth_verified (reason=protect_archive) ÷ protect_archive_clicked.
        Low conversion may mean the archive does not feel valuable enough yet — not missing auth features.
      </p>

      <ul className="space-y-1 text-sm text-zinc-500">
        {report.lines.map((line) => (
          <li key={line}>{line}</li>
        ))}
      </ul>

      <div className="overflow-x-auto rounded-xl border border-white/10">
        <table className="w-full text-left text-sm">
          <thead>
            <tr className="border-b border-white/10 text-xs uppercase tracking-wide text-zinc-500">
              <th className="px-4 py-3">Reason</th>
              <th className="px-4 py-3">Prompts</th>
              <th className="px-4 py-3">Verified</th>
              <th className="px-4 py-3">Rate</th>
            </tr>
          </thead>
          <tbody>
            {report.funnelByReason.map((row) => (
              <tr key={row.reason} className="border-b border-white/5 text-zinc-400">
                <td className="px-4 py-2 font-mono text-xs">{row.reason}</td>
                <td className="px-4 py-2">{row.promptsShown}</td>
                <td className="px-4 py-2">{row.verified}</td>
                <td className="px-4 py-2">{formatRate(row.conversionRate)}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      <div className="rounded-xl border border-amber-500/20 bg-amber-950/10 px-4 py-4">
        <p className="text-xs uppercase tracking-wider text-amber-200/80">Roadmap freeze</p>
        <p className="mt-2 text-sm text-zinc-400">
          Build only after known: {AUTH_VALUE_ROADMAP_FREEZE.pausedUntilKnown.join(" · ")}
        </p>
        <p className="mt-3 text-xs text-zinc-600">Do not build: {report.pausedBuilds.join(" · ")}</p>
      </div>

      <div className="rounded-xl border border-dashed border-white/10 px-4 py-4">
        <p className="text-xs uppercase tracking-wider text-zinc-500">Manual founder tests (6)</p>
        <ol className="mt-4 space-y-6">
          {AUTH_VALUE_MANUAL_SCENARIOS.map((s) => (
            <li key={s.id} className="text-sm text-zinc-400">
              <p className="font-medium text-zinc-200">
                {s.title}
              </p>
              <ul className="mt-2 list-disc space-y-1 pl-5 text-xs">
                {s.steps.map((step) => (
                  <li key={step}>{step}</li>
                ))}
              </ul>
              <p className="mt-2 text-xs text-emerald-400/80">Pass: {s.pass}</p>
              <p className="text-xs text-amber-400/80">Fail: {s.fail}</p>
            </li>
          ))}
        </ol>
      </div>
    </section>
  );
}

function Metric({
  label,
  value,
  highlight = false,
}: {
  label: string;
  value: string | number;
  highlight?: boolean;
}) {
  return (
    <div
      className={`rounded-xl border px-4 py-3 ${highlight ? "border-violet-500/30 bg-violet-950/20" : "border-white/10 bg-zinc-900/40"}`}
    >
      <dt className="text-xs text-zinc-500">{label}</dt>
      <dd className="mt-1 text-xl font-semibold tabular-nums text-white">{value}</dd>
    </div>
  );
}
