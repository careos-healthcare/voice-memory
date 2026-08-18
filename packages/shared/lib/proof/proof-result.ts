export type ProofVerdict = "PASS" | "DEPLOY_BLOCKED" | "DEVICE_BLOCKED" | "STAGING_BLOCKED" | "FAIL";

export type ProofCheckStatus = "pass" | "fail" | "blocked" | "skip";

export interface ProofCheck {
  name: string;
  status: ProofCheckStatus;
  detail: string;
}

export interface ProofReport {
  verdict: ProofVerdict;
  label: string;
  checks: ProofCheck[];
}

export function summarizeVerdict(checks: ProofCheck[]): ProofVerdict {
  if (checks.some((c) => c.status === "fail")) return "FAIL";
  if (checks.some((c) => c.status === "blocked")) return "DEPLOY_BLOCKED";
  return "PASS";
}

export function formatProofChecks(checks: ProofCheck[]): void {
  for (const check of checks) {
    const tag = check.status.toUpperCase().padEnd(8);
    console.log(`${tag} ${check.name}: ${check.detail}`);
  }
}
