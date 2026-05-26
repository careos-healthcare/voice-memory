import {
  isInvalidEntryRouteId,
  isPlaceholderEntryId,
  shouldRunEntryPresentationBuilders,
} from "@/lib/entry/entry-route-guard";

export interface EntryRouteTestResult {
  scenario: string;
  passed: boolean;
  failedAssertions: string[];
}

export interface EntryRouteTestReport {
  results: EntryRouteTestResult[];
  allPassed: boolean;
  failed: number;
}

function assertInvalidIds(): EntryRouteTestResult {
  const failures: string[] = [];
  const invalid = [
    "",
    "YOUR_RECENT_ENTRY_ID",
    "YOUR_ENTRY_ID",
    "PLACEHOLDER",
    "<entry-id>",
    "not-a-uuid",
    "abc",
  ];

  for (const id of invalid) {
    if (!isInvalidEntryRouteId(id)) {
      failures.push(`expected invalid route id: ${id}`);
    }
    if (!isPlaceholderEntryId(id) && id !== "not-a-uuid" && id !== "abc" && id !== "") {
      // placeholder-specific ids should also match placeholder helper
    }
  }

  if (!isPlaceholderEntryId("YOUR_RECENT_ENTRY_ID")) {
    failures.push("YOUR_RECENT_ENTRY_ID must be placeholder");
  }

  if (shouldRunEntryPresentationBuilders("YOUR_RECENT_ENTRY_ID", undefined, { loading: false })) {
    failures.push("builders must not run for placeholder id");
  }

  if (shouldRunEntryPresentationBuilders("", undefined, { loading: false })) {
    failures.push("builders must not run for empty id");
  }

  return {
    scenario: "invalid_and_placeholder_entry_ids",
    passed: failures.length === 0,
    failedAssertions: failures,
  };
}

function assertValidUuidAllowsBuildersWhenEntryPresent(): EntryRouteTestResult {
  const failures: string[] = [];
  const id = "550e8400-e29b-41d4-a716-446655440000";
  if (isInvalidEntryRouteId(id)) {
    failures.push("valid uuid should not be invalid route id");
  }
  const entry = {
    id,
    createdAt: new Date().toISOString(),
    transcript: "test",
    reflection: {
      mood: "",
      emotionalIntensity: 0,
      recurringThemes: [],
      hiddenConcern: "",
      positiveSignal: "",
      recommendation: "",
    },
    durationSeconds: 1,
    audioId: "",
  };
  if (!shouldRunEntryPresentationBuilders(id, entry, { loading: false })) {
    failures.push("builders should run for valid id with entry");
  }
  if (shouldRunEntryPresentationBuilders(id, entry, { loading: true })) {
    failures.push("builders must not run while loading");
  }
  return {
    scenario: "valid_uuid_entry_builder_gate",
    passed: failures.length === 0,
    failedAssertions: failures,
  };
}

export function runEntryRouteTests(): EntryRouteTestReport {
  const results = [assertInvalidIds(), assertValidUuidAllowsBuildersWhenEntryPresent()];
  const failed = results.filter((row) => !row.passed).length;
  return { results, allPassed: failed === 0, failed };
}

export function runEntryRouteTestsForCi(): EntryRouteTestReport {
  return runEntryRouteTests();
}
