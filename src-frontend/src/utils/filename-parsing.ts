export type Model = 'MODEL:01' | 'MODEL:02';

export const isModelString = (input: string): input is Model =>
  input === 'MODEL:01' || input === 'MODEL:02';

export type FirmwareInfo = {
  version: string;
  model: 'MODEL:01' | 'MODEL:02';
};

/**
 * Parses a firmware filename into a strongly-typed object.
 * @param filename The firmware filename (e.g. "M8_V6_2_0_BETA8A_MODEL02.hex")
 * @returns An object with `version` and `model` fields, or null if parsing fails.
 */
export const parseFirmwareFilename = (filename: string): FirmwareInfo | null => {
  const base = filename.replace(/\.hex$/i, '');

  const regex = /^M8_V(\d+)_(\d+)_(\d+)(?:_BETA(\d+)([A-Z])?)?(?:([A-Z]))?(?:_MODEL(\d+))?$/i;

  const match = base.match(regex);

  if (!match) {
    return null;
  }

  const [, major, minor, patch, betaNum, betaLetter, patchLetter, modelNum] = match;

  let version = `${major}.${minor}.${patch}`;

  if (betaNum) {
    version += ` Beta ${betaNum}${betaLetter || ''}`;
  } else if (patchLetter) {
    version += patchLetter;
  }

  const model = `MODEL:${modelNum ?? '01'}`;

  if (!isModelString(model)) {
    return null;
  }

  return { version, model };
};
