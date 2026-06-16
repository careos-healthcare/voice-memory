import storiesData from "@/data/archive-proof-stories.json";

export interface ArchiveProofStory {
  id: string;
  quote: string;
}

export interface ArchiveProofStoriesData {
  label: string;
  stories: ArchiveProofStory[];
}

export function getArchiveProofStories(): ArchiveProofStoriesData {
  return storiesData as ArchiveProofStoriesData;
}
