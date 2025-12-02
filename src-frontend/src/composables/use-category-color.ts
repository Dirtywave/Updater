const colors = [
  'pink-12',
  'light-green-13',
  'yellow-13',
  'cyan-12',
  'purple-12',
  'red-12',
  'light-blue-12',
];

let index = -1;

const colorsMap: Record<string, string> = {};

export const useCategoryColor = () => {
  const getColor = (category: string) => {
    const key = category.toUpperCase();

    if (!(key in colorsMap)) {
      colorsMap[key] = colors[++index % colors.length]!;
    }

    return colorsMap[key];
  };

  return getColor;
};
