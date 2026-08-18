export interface ContradictionPair {
  left: string;
  right: string;
  label: string;
}

const PAIRS: ContradictionPair[] = [
  { left: "leave", right: "stay", label: "leave vs stay" },
  { left: "quit", right: "stay", label: "quit vs stay" },
  { left: "angry", right: "calm", label: "angry vs calm" },
  { left: "furious", right: "fine", label: "angry vs calm" },
  { left: "certain", right: "uncertain", label: "certain vs uncertain" },
  { left: "sure", right: "not sure", label: "certain vs uncertain" },
  { left: "hopeful", right: "flat", label: "hopeful vs flat" },
  { left: "excited", right: "done", label: "hopeful vs flat" },
  { left: "want to", right: "don't want", label: "want vs don't want" },
  { left: "want to", right: "do not want", label: "want vs don't want" },
  { left: "done", right: "not done", label: "done vs not done" },
  { left: "finished", right: "nowhere", label: "done vs not done" },
  { left: "can", right: "can't", label: "can vs can't" },
  { left: "can", right: "cannot", label: "can vs can't" },
  { left: "ready", right: "not ready", label: "ready vs not ready" },
];

function normalize(s: string): string {
  return s.toLowerCase().replace(/[^\w\s']/g, " ");
}

function containsWord(haystack: string, word: string): boolean {
  const re = new RegExp(`\\b${word.replace(/'/g, "'?")}\\b`, "i");
  return re.test(haystack);
}

export function detectResurfacingContradiction(
  pastText: string,
  currentText: string,
): { signal: string | null; changeLine: string | null } {
  const past = normalize(pastText);
  const current = normalize(currentText);
  if (!past.trim() || !current.trim()) {
    return { signal: null, changeLine: null };
  }

  for (const pair of PAIRS) {
    const pastHasLeft = containsWord(past, pair.left);
    const pastHasRight = containsWord(past, pair.right);
    const curHasLeft = containsWord(current, pair.left);
    const curHasRight = containsWord(current, pair.right);

    if (pastHasLeft && curHasRight && !pastHasRight) {
      return {
        signal: pair.label,
        changeLine: `Earlier you sounded closer to "${pair.left}". This one sounds more like "${pair.right}".`,
      };
    }
    if (pastHasRight && curHasLeft && !pastHasLeft) {
      return {
        signal: pair.label,
        changeLine: `Earlier you sounded closer to "${pair.right}". This one sounds more like "${pair.left}".`,
      };
    }
    if (pastHasLeft && curHasLeft && pastHasRight !== curHasRight) {
      return {
        signal: pair.label,
        changeLine: "These two entries pull in different directions.",
      };
    }
  }

  const contradictionMarkers =
    /\b(but|however|although|on the other hand|then again)\b/i;
  if (contradictionMarkers.test(current) && past.length > 20) {
    return {
      signal: "contradiction markers in newer entry",
      changeLine: "This changed from what you said before.",
    };
  }

  return { signal: null, changeLine: null };
}

export function contradictionAwareSubline(changeLine: string | null): string | null {
  if (!changeLine) return null;
  return changeLine;
}
