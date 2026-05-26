const LOW_MEMORY_DEVICE_MEMORY_GB = 4;

export interface LightweightLimits {
  active: boolean;
  maxAnalyticsEvents: number;
  deferResurfacingMs: number;
}

let cachedLimits: LightweightLimits | null = null;

function detectLowMemoryDevice(): boolean {
  if (typeof navigator === "undefined") return false;
  const memory = (navigator as Navigator & { deviceMemory?: number }).deviceMemory;
  if (typeof memory === "number" && memory > 0 && memory <= LOW_MEMORY_DEVICE_MEMORY_GB) {
    return true;
  }
  if (navigator.hardwareConcurrency > 0 && navigator.hardwareConcurrency <= 4) {
    return true;
  }
  return false;
}

export function getLightweightLimits(): LightweightLimits {
  if (cachedLimits) return cachedLimits;
  const active = detectLowMemoryDevice();
  cachedLimits = {
    active,
    maxAnalyticsEvents: active ? 180 : 500,
    deferResurfacingMs: active ? 120 : 0,
  };
  return cachedLimits;
}

export function isLightweightMode(): boolean {
  return getLightweightLimits().active;
}

export function resurfacingDeferMs(): number {
  return getLightweightLimits().deferResurfacingMs;
}
