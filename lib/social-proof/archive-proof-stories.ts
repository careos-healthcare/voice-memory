export interface ArchiveProofStory {
  id: string;
  quote: string;
}

export interface ArchiveProofStoriesData {
  label: string;
  stories: ArchiveProofStory[];
}

const DEFAULT_STORIES: ArchiveProofStoriesData = {
  label: "Archive proof stories",
  stories: [],
};

export function getArchiveProofStories(): ArchiveProofStoriesData {
  return DEFAULT_STORIES;
}
