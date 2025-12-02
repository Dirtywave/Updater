import { storeToRefs } from 'pinia';
import { Notify } from 'quasar';
import { useFirmwareStore } from 'src/stores/firmware';
import type {
  ChangelogEntry,
  ChangelogSection,
  Firmware,
  FirmwareMetadata,
  FirmwareSansRealizedFileInfo,
} from 'src/types';
import { buildGitHubApiFetchArgs } from 'src/utils';
import type { Ref } from 'vue';

const fetchWithTimeout = async (
  input: Parameters<typeof fetch>[0],
  init: RequestInit = {},
  timeoutMs = 15000,
) => {
  const controller = new AbortController();
  const id = setTimeout(() => controller.abort(), timeoutMs);
  try {
    return await fetch(input, { ...init, signal: controller.signal });
  } finally {
    clearTimeout(id);
  }
};

const changelogUrl = 'https://api.github.com/repos/Dirtywave/M8Firmware/contents/changelog.txt';

const entryRegex = /((?<rawType>Fix|Improved|New)(?::|;)) (?<description>.*)$/;

const versionHeaderRegex = /^\d{4}-\d\d-\d\d - Version/;

export const parseVersion = (versionBlob: string[]): FirmwareSansRealizedFileInfo => {
  let sectionId = 0;

  const [header, ...changelogLines] = versionBlob;

  if (!header || !changelogLines) {
    throw new Error(
      'parseVersion: Failed to parse firmware version information (header or changelog lines missing)',
    );
  }

  const [date, version] = header.split(' - ');

  if (!date || !version) {
    throw new Error(
      'parseVersion: Failed to parse firmware version information (date or version missing)',
    );
  }

  const changelog: ChangelogSection[] = [];

  let currentEntry: ChangelogEntry | null = null;

  let currentSection: ChangelogSection = {
    entries: [],
    id: sectionId++,
  };

  changelogLines.forEach((line) => {
    // This is a nested detail line
    if (line.startsWith('-   ')) {
      if (currentEntry) {
        currentEntry.details = currentEntry.details || [];

        currentEntry.details.push(line.replace('-   ', ''));
      }
    } else if (line.startsWith('- ') || line.match(/^\w+: .*$/)) {
      if (currentEntry) {
        currentSection.entries.push(currentEntry);
      }

      // Generalize special case for lines starting with '- Fix from ... '
      if (line.startsWith('- Fix from ')) {
        currentEntry = {
          description: line.replace('- Fix ', ''),
          type: 'fix',
        };
      } else {
        const { rawType = null, description = null } =
          entryRegex.exec(line.replace('- ', ''))?.groups ?? {};

        if (!rawType || !description) {
          currentEntry = {
            description: line.replace('- ', ''),
            type: 'change',
          };
        } else {
          const type = rawType.toLowerCase();

          currentEntry = {
            description,
            type:
              type === 'fix'
                ? 'fix'
                : type === 'improved'
                  ? 'improved'
                  : type === 'new'
                    ? 'new'
                    : 'change',
          };
        }
      }
    } else {
      changelog.push(currentSection);

      currentSection = {
        entries: [],
        id: sectionId++,
        title: line,
      };
    }
  });

  return {
    changelog,
    date,
    version: version.replace('Version ', ''),
  };
};

export const parseChangelog = (changelog: string): FirmwareSansRealizedFileInfo[] => {
  const versionBlobs: string[][] = [];

  changelog.split('\n').forEach((line) => {
    if (versionHeaderRegex.test(line)) {
      versionBlobs.push([]);
    }

    versionBlobs[versionBlobs.length - 1]?.push(line);
  });

  return versionBlobs.map(parseVersion);
};

const fetchChangelog = async () => {
  const [url, init] = buildGitHubApiFetchArgs(changelogUrl);

  const response = await fetchWithTimeout(url, init);

  if (!response.ok) {
    throw new Error(await response.json().then((data) => JSON.stringify(data, null, 2)));
    // throw new Error('Network response was not ok');
  }

  return await response.text();
};

type RawFirmwareMetadata = {
  _links: {
    git: string;
    html: string;
    self: string;
  };
  git_url: string;
  html_url: string;
  name: string;
  path: string;
  sha: string;
  size: number;
  type: string;
  url: string;
};

const getFirmwareMetadatas = async (): Promise<FirmwareMetadata[]> => {
  const [releasesUrl, releasesInit] = buildGitHubApiFetchArgs(
    'https://api.github.com/repos/Dirtywave/M8Firmware/contents/Releases',
  );

  const result = await fetchWithTimeout(releasesUrl, releasesInit);

  const json = (await result.json()) as RawFirmwareMetadata[];

  // The latest firmware is not present in the Releases directory, and lives at the top-level
  const [latestUrl, latestInit] = buildGitHubApiFetchArgs(
    'https://api.github.com/repos/Dirtywave/M8Firmware/contents/M8Firmware.zip',
    'object',
  );

  const latestResult = await fetchWithTimeout(latestUrl, latestInit);

  const latestJson = (await latestResult.json()) as RawFirmwareMetadata;

  json.push(latestJson);

  const parsedVersions = json.map(({ path, name, size }) => ({
    path,
    size,
    version: (
      /V(?<version>(\d_{0,1})+[A-Z]{0,1})/g.exec(name)?.groups?.['version'] ?? ''
    ).replaceAll('_', '.'),
  }));

  return parsedVersions.reverse();
};

const getLatestChangelog = async () => {
  try {
    const changelog = await fetchChangelog();

    return parseChangelog(changelog);
  } catch (e) {
    const message = 'Failed to fetch and parse latest changelog';

    console.error(message, e);

    Notify.create({
      message: `${e instanceof Error ? e.message : String(e) || message}`,
      type: 'negative',
    });
  }
};

const mergeFirmwareData = ({
  changelog,
  metadata,
}: {
  changelog: FirmwareSansRealizedFileInfo[];
  metadata: FirmwareMetadata[];
}): Firmware[] => {
  const mergedFirmwareData: Record<string, Firmware> = {};

  changelog.forEach((firmware) => {
    mergedFirmwareData[firmware.version] = { ...firmware, path: '' };
  });

  // Group versions by their base version (without alphabetic suffix)
  const versionGroups: Record<string, string[]> = {};

  changelog.forEach((firmware) => {
    const baseVersion = firmware.version.replace(/[A-Z]$/, '');

    if (!versionGroups[baseVersion]) {
      versionGroups[baseVersion] = [];
    }

    versionGroups[baseVersion].push(firmware.version);
  });

  Object.values(versionGroups).forEach((group) => group.sort());

  const archiveMapping: Record<string, string> = {};

  Object.entries(versionGroups).forEach(([baseVersion, versions]) => {
    if (versions.length > 1) {
      const latestPatch = versions[versions.length - 1];

      if (latestPatch) {
        archiveMapping[baseVersion] = latestPatch;
      }
    } else {
      if (versions[0]) {
        archiveMapping[baseVersion] = versions[0];
      }
    }
  });

  metadata.forEach((metadataItem) => {
    const { version } = metadataItem;
    const baseVersion = version.replace(/[A-Z]$/, '');

    const targetVersion = archiveMapping[baseVersion];

    if (targetVersion && mergedFirmwareData[targetVersion]) {
      // eslint-disable-next-line @typescript-eslint/no-unused-vars
      const { version, ...metadataWithoutVersion } = metadataItem;

      mergedFirmwareData[targetVersion] = {
        ...mergedFirmwareData[targetVersion],
        ...metadataWithoutVersion,
      };
    }
  });

  return Object.values(mergedFirmwareData).sort((a, b) => b.version.localeCompare(a.version));
};

// const mergeFirmwareData = ({
// 	changelog,
// 	metadata,
// }: {
// 	changelog: FirmwareSansRealizedFileInfo[];
// 	metadata: FirmwareMetadata[];
// }): Firmware[] => {
// 	const mergedFirmwareData: Record<string, Firmware> = {};

// 	changelog.forEach((firmware) => {
// 		mergedFirmwareData[firmware.version] = {...firmware, path: '' };
// 	});

// 	metadata.forEach((metadata) => {
// 		const { version } = metadata;

// 		const entry = mergedFirmwareData[version] ?? {};

// 		if (entry) {
// 			mergedFirmwareData[version] = { ...entry, ...metadata };
// 		}
// 	});

// 	return Object.values(mergedFirmwareData).sort((a, b) =>
// 		b.version.localeCompare(a.version),
// 	);
// };

const getAndSetFirmwareData = async (firmwareRef: Ref<Firmware[]>) => {
  try {
    const changelog = await getLatestChangelog();

    const metadata = await getFirmwareMetadatas();

    if (changelog && metadata) {
      // The latest firmware doesn't have the version in its filename, and so
      // the version of metadata[0] should be an empty string. We pair it up with
      // the first entry in the parsed changelog, which should correlate to
      // the latest version of the firmware.
      if (metadata[0] && !metadata[0].version) {
        metadata[0].version = changelog[0]?.version ?? '';
      }

      const mergedFirmwareData = mergeFirmwareData({ changelog, metadata });

      firmwareRef.value = mergedFirmwareData;
    }
  } catch (e) {
    const message = 'Failed to fetch and parse firmware data';

    console.error(message, e);

    Notify.create({
      message,
      type: 'negative',
    });
  }
};

export const useFirmwareList = () => {
  const { firmwares } = storeToRefs(useFirmwareStore());

  const fetchFirmwareList = async (): Promise<Firmware[]> => {
    const firmwareDataUpsertPromise = getAndSetFirmwareData(firmwares);

    // We've cached the previously parsed changelog to disk.
    // Go ahead and return that while updating changelog in background.
    if (firmwares.value.length) {
      return firmwares.value;
    }

    await firmwareDataUpsertPromise;

    return firmwares.value;
  };

  return {
    fetchFirmwareList,
    firmwares,
  };
};
