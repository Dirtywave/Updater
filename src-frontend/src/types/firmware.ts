export type ChangelogEntry = {
  description: string;
  type: 'change' | 'fix' | 'improved' | 'new';
  details?: string[];
};

export type ChangelogSection = {
  entries: ChangelogEntry[];
  id: number;
  title?: string;
};

export type FirmwareMetadata = {
  path: string;
  version: string;
};

export type Firmware = FirmwareMetadata & {
  changelog?: ChangelogSection[];
  date?: string;
};

export type FirmwareSansRealizedFileInfo = Omit<Firmware, 'path' | 'size'>;

export const changelogEntryTypeColors: Record<ChangelogEntry['type'], string> = {
  change: 'dirty-white', // "purple-12",
  fix: 'dirty-white', // "amber-14",
  improved: 'dirty-white', // "teal-13",
  new: 'dirty-white', // "light-green-13",
};
