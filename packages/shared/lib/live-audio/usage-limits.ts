const LIVE_AUDIO_DAILY_LIMIT = Number(
  process.env.VOICEMEMORY_DAILY_LIVE_AUDIO_LIMIT ?? "10",
);
const LIVE_AUDIO_MINUTE_LIMIT = Number(
  process.env.VOICEMEMORY_MINUTE_LIVE_AUDIO_LIMIT ?? "3",
);

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
  const minuteCounterKey = `${subject}:${minuteKey()}`;
  const minuteCount = minuteMap().get(minuteCounterKey) ?? 0;
  if (minuteCount >= LIVE_AUDIO_MINUTE_LIMIT) {
    return { allowed: false, reason: "minute_burst" };
  }
  minuteMap().set(minuteCounterKey, minuteCount + 1);

  const dayCounterKey = `${subject}:${dayKey()}`;
  const dayCount = dayMap().get(dayCounterKey) ?? 0;
  if (dayCount >= LIVE_AUDIO_DAILY_LIMIT) {
    return {
      allowed: false,
      reason: "daily_cap",
      dailyCount: dayCount,
      dailyLimit: LIVE_AUDIO_DAILY_LIMIT,
    };
  }
  dayMap().set(dayCounterKey, dayCount + 1);
  return {
    allowed: true,
    dailyCount: dayCount + 1,
    dailyLimit: LIVE_AUDIO_DAILY_LIMIT,
  };
}

export function resetLiveAudioUsageForTest(): void {
  minuteMap().clear();
  dayMap().clear();
}
