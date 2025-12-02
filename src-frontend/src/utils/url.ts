const template =
  'https://github.com/Dirtywave/M8Firmware/raw/refs/heads/main/Releases/M8Firmware_V<VERSION>.zip';

const endsWithLetter = /[a-zA-Z]$/;

export const getFirmwareDownloadLink = async (version: string | null): Promise<string | null> => {
  if (version) {
    const underscored = version.replace(/\./g, '_');

    const url = template.replace('<VERSION>', underscored);

    const response = await fetch(url, {
      method: 'GET',
    });

    if (!response.ok) {
      if (endsWithLetter.test(version)) {
        return await getFirmwareDownloadLink(version.slice(0, -1));
      }
    }

    return url;
  }

  return null;
};

export const buildGitHubApiFetchArgs = (
  url: Parameters<typeof fetch>[0],
  accept = 'raw',
): Parameters<typeof fetch> => {
  const init: RequestInit = {
    headers: {
      Accept: `application/vnd.github.${accept}+json`,
      'User-Agent': 'com.dirtywave.updater',
      'X-GitHub-Api-Version': '2022-11-28',
    },
  };

  if (import.meta.env.GITHUB_API_TOKEN) {
    (init.headers as Record<string, string>).Authorization =
      `Bearer ${import.meta.env.GITHUB_API_TOKEN}`;
  }

  return [url, init];
};

export const resourcesAndDownloadsUrl = 'https://dirtywave.com/pages/resources-downloads';

export const fetchM8OperationManualDownloadLink = async () =>
  await fetch(resourcesAndDownloadsUrl, {
    cache: 'no-cache',
  })
    .then((response) => response.text())
    .then((content) => {
      const parser = new DOMParser();

      const resourcesDocument = parser.parseFromString(content, 'text/html');

      const pdfLink = resourcesDocument.querySelector<HTMLAnchorElement>('a[href*="pdf"]');

      return pdfLink?.href ?? resourcesAndDownloadsUrl;
    })
    .catch(() => resourcesAndDownloadsUrl);
