import type { ApiUsageKind } from "@/lib/server/api-usage-store";
import {
  estimateForOpenAiKind,
  maxEstimateForOpenAiKind,
  type MicroUsd,
  microUsdToUsd,
} from "@/lib/server/openai-cost-estimator";
import { reserveOpenAiSpend } from "@/lib/server/openai-spend-store";

export type OpenAiBudgetScope =
  | "global"
  | "ip"
  | "device"
  | "user"
  | "route";

export interface OpenAiBudgetGuardContext {
  subject: string;
  via: "session" | "capture";
  userId?: string;
  deviceId?: string;
}

export interface OpenAiBudgetCheckResult {
  allowed: boolean;
  scope?: OpenAiBudgetScope;
  spentMicro?: number;
  limitMicro?: number;
}

function envMicroUsd(name: string, defaultUsd: number): MicroUsd {
  const raw = process.env[name]?.trim();
  if (!raw) return Math.ceil(defaultUsd * 1_000_000);
  const parsed = Number(raw);
  if (!Number.isFinite(parsed) || parsed < 0) {
    return Math.ceil(defaultUsd * 1_000_000);
  }
  return Math.ceil(parsed * 1_000_000);
}

export function getOpenAiBudgetLimits(): {
  globalMicro: MicroUsd;
  ipMicro: MicroUsd;
  deviceMicro: MicroUsd;
  userMicro: MicroUsd;
  routeMicro: Record<Exclude<ApiUsageKind, "attest">, MicroUsd>;
} {
  return {
    globalMicro: envMicroUsd("VOICEMEMORY_OPENAI_GLOBAL_DAILY_BUDGET_USD", 25),
    ipMicro: envMicroUsd("VOICEMEMORY_OPENAI_IP_DAILY_BUDGET_USD", 1.5),
    deviceMicro: envMicroUsd("VOICEMEMORY_OPENAI_DEVICE_DAILY_BUDGET_USD", 2),
    userMicro: envMicroUsd("VOICEMEMORY_OPENAI_USER_DAILY_BUDGET_USD", 2),
    routeMicro: {
      transcribe: envMicroUsd("VOICEMEMORY_OPENAI_ROUTE_TRANSCRIBE_DAILY_USD", 12),
      analyze: envMicroUsd("VOICEMEMORY_OPENAI_ROUTE_ANALYZE_DAILY_USD", 8),
      atmosphere: envMicroUsd("VOICEMEMORY_OPENAI_ROUTE_ATMOSPHERE_DAILY_USD", 4),
    },
  };
}

export function isOpenAiKillSwitchActive(): boolean {
  return process.env.VOICEMEMORY_OPENAI_KILL_SWITCH === "true";
}

interface BudgetSubject {
  subject: string;
  scope: OpenAiBudgetScope;
  limitMicro: MicroUsd;
}

export function subjectsForOpenAiBudget(
  ctx: OpenAiBudgetGuardContext,
  ipHash: string,
  kind: ApiUsageKind,
): BudgetSubject[] {
  const limits = getOpenAiBudgetLimits();
  const rows: BudgetSubject[] = [
    { subject: "global:openai", scope: "global", limitMicro: limits.globalMicro },
    { subject: `ip:${ipHash}`, scope: "ip", limitMicro: limits.ipMicro },
  ];

  if (kind !== "attest") {
    rows.push({
      subject: `route:${kind}`,
      scope: "route",
      limitMicro: limits.routeMicro[kind],
    });
  }

  if (ctx.userId) {
    rows.push({
      subject: `user:${ctx.userId}`,
      scope: "user",
      limitMicro: limits.userMicro,
    });
  }

  if (ctx.deviceId) {
    rows.push({
      subject: `device:${ctx.deviceId}`,
      scope: "device",
      limitMicro: limits.deviceMicro,
    });
  } else if (ctx.via === "capture" && ctx.subject.startsWith("device:")) {
    rows.push({
      subject: ctx.subject,
      scope: "device",
      limitMicro: limits.deviceMicro,
    });
  }

  return rows;
}

export async function reserveOpenAiBudget(
  ctx: OpenAiBudgetGuardContext,
  ipHash: string,
  kind: ApiUsageKind,
  estimateMicro?: MicroUsd,
): Promise<OpenAiBudgetCheckResult> {
  if (isOpenAiKillSwitchActive()) {
    return { allowed: false, scope: "global" };
  }

  if (kind === "attest") {
    return { allowed: true };
  }

  const delta = estimateMicro ?? maxEstimateForOpenAiKind(kind);
  if (delta <= 0) return { allowed: true };

  for (const row of subjectsForOpenAiBudget(ctx, ipHash, kind)) {
    const result = await reserveOpenAiSpend(row.subject, delta, row.limitMicro);
    if (!result.ok) {
      return {
        allowed: false,
        scope: row.scope,
        spentMicro: result.spent,
        limitMicro: result.limit,
      };
    }
  }

  return { allowed: true };
}

export function estimateOpenAiBudgetCharge(
  kind: ApiUsageKind,
  options?: {
    transcriptChars?: number;
    durationSeconds?: number;
    audioBytes?: number;
  },
): MicroUsd {
  return estimateForOpenAiKind(kind, options);
}

export function logOpenAiBudgetDenial(
  scope: OpenAiBudgetScope | undefined,
  kind: ApiUsageKind,
  spentMicro?: number,
  limitMicro?: number,
): void {
  console.warn(
    "[ArchiveMe OpenAI budget]",
    JSON.stringify({
      kind,
      scope: scope ?? "unknown",
      spentUsd: spentMicro !== undefined ? microUsdToUsd(spentMicro) : null,
      limitUsd: limitMicro !== undefined ? microUsdToUsd(limitMicro) : null,
    }),
  );
}
