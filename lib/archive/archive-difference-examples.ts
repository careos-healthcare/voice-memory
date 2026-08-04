export interface ArchiveDifferenceExample {
  withoutArchive: string;
  withArchive: string;
}

export const ARCHIVE_DIFFERENCE_EXAMPLES: readonly ArchiveDifferenceExample[] = [
  {
    withoutArchive: "I had a bad day.",
    withArchive: "This is the 4th time criticism appeared this month.",
  },
  {
    withoutArchive: "I'm stressed about work again.",
    withArchive: "Work pressure has shown up in six saved moments since January.",
  },
  {
    withoutArchive: "I don't know why I keep snapping at home.",
    withArchive: "Family tension appeared before three big work weeks.",
  },
  {
    withoutArchive: "Maybe I'm overreacting.",
    withArchive: "The archive has seen this reaction after similar meetings.",
  },
] as const;

export function pickArchiveDifferenceExample(seed = 0): ArchiveDifferenceExample {
  const index =
    ((seed % ARCHIVE_DIFFERENCE_EXAMPLES.length) + ARCHIVE_DIFFERENCE_EXAMPLES.length) %
    ARCHIVE_DIFFERENCE_EXAMPLES.length;
  return ARCHIVE_DIFFERENCE_EXAMPLES[index]!;
}
