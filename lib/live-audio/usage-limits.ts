function configuredLimit(name: string, developmentDefault: number): number {
  const raw = process.env[name]?.trim();
  if (!raw) {
    if (process.env.NODE_ENV === "production") {
      throw new Error(`USAGE_RATE_LIMIT_CONFIG_INVALID:${name}`);
    }
    return developmentDefault;
  }
  const value = Number(raw);
  if (!Number.isSafeInteger(value) || value <= 0) {
    throw new Error(`USAGE_RATE_LIMIT_CONFIG_INVALID:${name}`);
  }
  return value;
}

const globalLimits = globalThis as typeof globalThis & {
  __vmLiveAudioMinute?: Map<string, number>;
  __vmLiveAudioDay?: Map<string, number>;
};

function minuteMap(): Map<string, number> {
  if (!globalLimits.__vmLiveAudioMinute) {
    globalLimits.__vmLiveAudioMinute = new Map();
  }
  return globalLimits.__vmLiveAudioMinute;
}

function dayMap(): Map<string, number> {
  if (!globalLimits.__vmLiveAudioDay) {
    globalLimits.__vmLiveAudioDay = new Map();
  }
  return globalLimits.__vmLiveAudioDay;
}

function dayKey(): string {
  return new Date().toISOString().slice(0, 10);
}

function minuteKey(): string {
  const d = new Date();
  return `${d.toISOString().slice(0, 16)}`;
}

export function checkAndRecordLiveAudioUsage(subject: string): {
  allowed: boolean;
  reason?: "minute_burst" | "daily_cap";
  dailyCount?: number;
  dailyLimit?: number;
} {
  const minuteLimit = configuredLimit("VOICEMEMORY_MINUTE_LIVE_AUDIO_LIMIT", 3);
  const dailyLimit = configuredLimit("VOICEMEMORY_DAILY_LIVE_AUDIO_LIMIT", 10);
  const minuteCounterKey = `${subject}:${minuteKey()}`;
  const minuteCount = minuteMap().get(minuteCounterKey) ?? 0;
  if (minuteCount >= minuteLimit) {
    return { allowed: false, reason: "minute_burst" };
  }
  minuteMap().set(minuteCounterKey, minuteCount + 1);

  const dayCounterKey = `${subject}:${dayKey()}`;
  const dayCount = dayMap().get(dayCounterKey) ?? 0;
  if (dayCount >= dailyLimit) {
    return {
      allowed: false,
      reason: "daily_cap",
      dailyCount: dayCount,
      dailyLimit,
    };
  }
  dayMap().set(dayCounterKey, dayCount + 1);
  return {
    allowed: true,
    dailyCount: dayCount + 1,
    dailyLimit,
  };
}

export function resetLiveAudioUsageForTest(): void {
  minuteMap().clear();
  dayMap().clear();
}
