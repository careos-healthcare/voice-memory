const RENAMES_KEY = "voicememory_territory_renames";
const ACTIVE_TERRITORY_KEY = "voicememory_active_territory_id";

function isBrowser(): boolean {
  return typeof window !== "undefined";
}

export function readTerritoryRenames(): Record<string, string> {
  if (!isBrowser()) return {};
  try {
    const raw = localStorage.getItem(RENAMES_KEY);
    return raw ? (JSON.parse(raw) as Record<string, string>) : {};
  } catch {
    return {};
  }
}

export function saveTerritoryRename(territoryId: string, label: string): void {
  if (!isBrowser()) return;
  const trimmed = label.trim();
  const renames = readTerritoryRenames();
  if (!trimmed) {
    delete renames[territoryId];
  } else {
    renames[territoryId] = trimmed;
  }
  localStorage.setItem(RENAMES_KEY, JSON.stringify(renames));
  window.dispatchEvent(new CustomEvent("voicememory:territory-preferences"));
}

export function resolveTerritoryLabel(
  territoryId: string,
  defaultLabel: string,
): string {
  const custom = readTerritoryRenames()[territoryId]?.trim();
  return custom || defaultLabel;
}

export function readActiveTerritoryId(): string | null {
  if (!isBrowser()) return null;
  return localStorage.getItem(ACTIVE_TERRITORY_KEY);
}

export function writeActiveTerritoryId(territoryId: string | null): void {
  if (!isBrowser()) return;
  if (territoryId) {
    localStorage.setItem(ACTIVE_TERRITORY_KEY, territoryId);
  } else {
    localStorage.removeItem(ACTIVE_TERRITORY_KEY);
  }
  window.dispatchEvent(new CustomEvent("voicememory:territory-preferences"));
}
