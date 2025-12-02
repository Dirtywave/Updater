export * from './changelog';
export * from './events';
export * from './serial';
export * from './text';
export * from './url';

type RGB = [number, number, number];

const extractChannels = (color: string): RGB =>
  ((color.match(/^#(..)(..)(..)$/)?.slice(1) as [string, string, string])?.map((color) =>
    parseInt(color, 16),
  ) as RGB) ?? [0, 0, 0];

export type ColorTweenOptions = {
  from: string;
  percentage: number;
  to: string;
};

export const colorTween = ({ from, percentage, to }: ColorTweenOptions) => {
  const fromRgb = extractChannels(from);
  const toRgb = extractChannels(to);

  const rgb = [
    fromRgb[0] + (fromRgb[0] <= toRgb[0] ? 1 : -1) * Math.abs(fromRgb[0] - toRgb[0]) * percentage,
    fromRgb[1] + (fromRgb[1] <= toRgb[1] ? 1 : -1) * Math.abs(fromRgb[1] - toRgb[1]) * percentage,
    fromRgb[2] + (fromRgb[2] <= toRgb[2] ? 1 : -1) * Math.abs(fromRgb[2] - toRgb[2]) * percentage,
  ];

  return `#${rgb.map((color) => Math.round(color).toString(16).padStart(2, '0')).join('')}`;
};
