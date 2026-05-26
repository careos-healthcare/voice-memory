import { buildQuietHomepagePresentation } from "@/lib/refinement/quiet-presentation";
import { buildQuietEntryPresentation } from "@/lib/refinement/quiet-presentation";
import { buildRevisitExperience } from "@/lib/refinement/revisit-experience";
import { flushPresentationSideEffects } from "@/lib/refinement/presentation-side-effects";
import {
  isPresentationBuildActive,
  runPresentationBuild,
} from "@/lib/tracking/presentation-guard";
import type { JournalEntry } from "@/types/journal";

export interface PresentationSideEffectsTestResult {
  scenario: string;
  passed: boolean;
  failedAssertions: string[];
}

export interface PresentationSideEffectsTestReport {
  results: PresentationSideEffectsTestResult[];
  allPassed: boolean;
  failed: number;
}

const HOMEPAGE_LIMITS = {
  continuation: 1,
  resurfacing: 2,
  familiarity: 2,
  rhythm: 1,
  familiarityResurfacing: 1,
  archiveGrowth: 1,
};

const ENTRY_LIMITS = {
  changeMoments: 1,
  familiarity: 1,
  familiarityResurfacing: 1,
  resurfacing: 2,
};

function installBrowserStorageMock(): () => void {
  const storage: Record<string, string> = {};
  const session: Record<string, string> = {};

  const localStorage = {
    getItem: (key: string) => storage[key] ?? null,
    setItem: (key: string, value: string) => {
      if (isPresentationBuildActive()) {
        throw new Error(`localStorage.setItem during presentation build: ${key}`);
      }
      storage[key] = value;
    },
    removeItem: (key: string) => {
      delete storage[key];
    },
  };

  const sessionStorage = {
    getItem: (key: string) => session[key] ?? null,
    setItem: (key: string, value: string) => {
      if (isPresentationBuildActive()) {
        throw new Error(`sessionStorage.setItem during presentation build: ${key}`);
      }
      session[key] = value;
    },
    removeItem: (key: string) => {
      delete session[key];
    },
  };

  const priorWindow = (globalThis as { window?: Window }).window;
  const priorLocal = (globalThis as { localStorage?: Storage }).localStorage;
  const priorSession = (globalThis as { sessionStorage?: Storage }).sessionStorage;

  (globalThis as { window: Window }).window = {
    localStorage,
    sessionStorage,
    location: { pathname: "/" },
  } as Window;
  (globalThis as { localStorage: Storage }).localStorage = localStorage as Storage;
  (globalThis as { sessionStorage: Storage }).sessionStorage = sessionStorage as Storage;

  return () => {
    if (priorWindow === undefined) {
      delete (globalThis as { window?: Window }).window;
    } else {
      (globalThis as { window?: Window }).window = priorWindow;
    }
    if (priorLocal === undefined) {
      delete (globalThis as { localStorage?: Storage }).localStorage;
    } else {
      (globalThis as { localStorage?: Storage }).localStorage = priorLocal;
    }
    if (priorSession === undefined) {
      delete (globalThis as { sessionStorage?: Storage }).sessionStorage;
    } else {
      (globalThis as { sessionStorage?: Storage }).sessionStorage = priorSession;
    }
  };
}

function emptyReflection(): JournalEntry["reflection"] {
  return {
    mood: "steady",
    emotionalIntensity: 0,
    recurringThemes: [],
    hiddenConcern: "",
    positiveSignal: "",
    recommendation: "",
  };
}

function sampleEntries(): JournalEntry[] {
  const now = new Date().toISOString();
  return [
    {
      id: "entry-a",
      createdAt: now,
      transcript: "I keep circling the same worry about work and whether it will settle.",
      reflection: emptyReflection(),
      durationSeconds: 42,
      audioId: "",
    },
    {
      id: "entry-b",
      createdAt: new Date(Date.now() - 5 * 24 * 60 * 60 * 1000).toISOString(),
      transcript: "Work still takes space but I sound a little further from the panic now.",
      reflection: emptyReflection(),
      durationSeconds: 38,
      audioId: "",
    },
  ];
}

function assertHomepageBuildNoSyncWrites(): PresentationSideEffectsTestResult {
  const failures: string[] = [];
  const restore = installBrowserStorageMock();
  try {
    const built = runPresentationBuild(() =>
      buildQuietHomepagePresentation([], HOMEPAGE_LIMITS),
    );
    flushPresentationSideEffects(built.sideEffects);
  } catch (error) {
    failures.push(error instanceof Error ? error.message : String(error));
  } finally {
    restore();
  }
  return {
    scenario: "homepage_presentation_build_no_sync_storage",
    passed: failures.length === 0,
    failedAssertions: failures,
  };
}

function assertEntryBuildNoSyncWrites(): PresentationSideEffectsTestResult {
  const failures: string[] = [];
  const restore = installBrowserStorageMock();
  try {
    const entries = sampleEntries();
    const built = runPresentationBuild(() =>
      buildQuietEntryPresentation(entries, "entry-b", ENTRY_LIMITS),
    );
    flushPresentationSideEffects(built.sideEffects);
  } catch (error) {
    failures.push(error instanceof Error ? error.message : String(error));
  } finally {
    restore();
  }
  return {
    scenario: "entry_presentation_build_no_sync_storage",
    passed: failures.length === 0,
    failedAssertions: failures,
  };
}

function assertRevisitBuildNoSyncWrites(): PresentationSideEffectsTestResult {
  const failures: string[] = [];
  const restore = installBrowserStorageMock();
  try {
    const entries = sampleEntries();
    const built = runPresentationBuild(() =>
      buildRevisitExperience(entries, "entry-b", {
        changeMoments: 1,
        familiarityResurfacing: 1,
        resurfacing: 2,
      }),
    );
    flushPresentationSideEffects(built.sideEffects);
  } catch (error) {
    failures.push(error instanceof Error ? error.message : String(error));
  } finally {
    restore();
  }
  return {
    scenario: "revisit_presentation_build_no_sync_storage",
    passed: failures.length === 0,
    failedAssertions: failures,
  };
}

function assertPresentationGuardDepth(): PresentationSideEffectsTestResult {
  const failures: string[] = [];
  let nested = false;
  runPresentationBuild(() => {
    nested = isPresentationBuildActive();
    runPresentationBuild(() => {
      if (!isPresentationBuildActive()) {
        failures.push("nested presentation build guard inactive");
      }
    });
  });
  if (!nested) failures.push("presentation build guard inactive at top level");
  return {
    scenario: "presentation_guard_reentrancy_depth",
    passed: failures.length === 0,
    failedAssertions: failures,
  };
}

export function runPresentationSideEffectsTests(): PresentationSideEffectsTestReport {
  const results = [
    assertPresentationGuardDepth(),
    assertHomepageBuildNoSyncWrites(),
    assertEntryBuildNoSyncWrites(),
    assertRevisitBuildNoSyncWrites(),
  ];
  const failed = results.filter((row) => !row.passed).length;
  return {
    results,
    allPassed: failed === 0,
    failed,
  };
}

export function runPresentationSideEffectsTestsForCi(): PresentationSideEffectsTestReport {
  return runPresentationSideEffectsTests();
}
