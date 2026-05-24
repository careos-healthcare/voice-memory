import type { TesterFeedbackKind, TesterFeedbackRecord } from "@/types/validation-phase";

const FEEDBACK_KEY = "voicememory_tester_feedback";
const MAX_RECORDS = 300;

export const TESTER_FEEDBACK_LABELS: Record<
  TesterFeedbackKind,
  { prompt: string; placeholder: string }
> = {
  felt_wrong: {
    prompt: "Something felt wrong",
    placeholder: "What felt off, generic, or untrue?",
  },
  really_landed: {
    prompt: "This really landed",
    placeholder: "What line or moment stayed with you?",
  },
  revisited_because: {
    prompt: "I revisited this because…",
    placeholder: "What pulled you back to an older entry?",
  },
  forgot_i_sounded: {
    prompt: "I forgot I sounded like this",
    placeholder: "What surprised you about your own voice?",
  },
};

function isBrowser(): boolean {
  return typeof window !== "undefined";
}

function readRaw(): TesterFeedbackRecord[] {
  if (!isBrowser()) return [];
  try {
    const raw = localStorage.getItem(FEEDBACK_KEY);
    if (!raw) return [];
    const parsed = JSON.parse(raw) as TesterFeedbackRecord[];
    return Array.isArray(parsed) ? parsed : [];
  } catch {
    return [];
  }
}

function writeRaw(records: TesterFeedbackRecord[]): void {
  if (!isBrowser()) return;
  localStorage.setItem(FEEDBACK_KEY, JSON.stringify(records.slice(-MAX_RECORDS)));
}

export function saveTesterFeedback(input: {
  kind: TesterFeedbackKind;
  text: string;
  entryId?: string;
  noteId?: string;
}): TesterFeedbackRecord {
  const trimmed = input.text.trim();
  if (!trimmed) {
    throw new Error("Add a short note.");
  }

  const record: TesterFeedbackRecord = {
    id: crypto.randomUUID(),
    kind: input.kind,
    text: trimmed.slice(0, 600),
    entryId: input.entryId,
    noteId: input.noteId,
    createdAt: new Date().toISOString(),
  };

  writeRaw([...readRaw(), record]);
  return record;
}

export function readTesterFeedback(): TesterFeedbackRecord[] {
  return readRaw().sort(
    (a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime(),
  );
}

export function readTesterFeedbackByKind(kind: TesterFeedbackKind): TesterFeedbackRecord[] {
  return readTesterFeedback().filter((row) => row.kind === kind);
}

export function clearTesterFeedback(): void {
  if (!isBrowser()) return;
  localStorage.removeItem(FEEDBACK_KEY);
}

export function buildTesterFeedbackExport(): {
  exportedAt: string;
  count: number;
  records: TesterFeedbackRecord[];
} {
  const records = readTesterFeedback();
  return {
    exportedAt: new Date().toISOString(),
    count: records.length,
    records,
  };
}

export function downloadTesterFeedbackJson(): void {
  if (!isBrowser()) return;

  const payload = buildTesterFeedbackExport();
  const blob = new Blob([JSON.stringify(payload, null, 2)], { type: "application/json" });
  const url = URL.createObjectURL(blob);
  const anchor = document.createElement("a");
  anchor.href = url;
  anchor.download = `tester-feedback-${payload.exportedAt.slice(0, 10)}.json`;
  anchor.click();
  URL.revokeObjectURL(url);
}
