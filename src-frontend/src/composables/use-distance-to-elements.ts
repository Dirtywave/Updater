import { useMouse, useWindowSize } from '@vueuse/core';
import { type Ref, computed } from 'vue';

const computeDistance = (x1: number, y1: number, x2: number, y2: number) => {
  const dx = x1 - x2;
  const dy = y1 - y2;

  return Math.sqrt(dx * dx + dy * dy);
};

export type useDistanceToElementsOptions = {
  threshold?: number;
};

export const useDistanceToElements = <T extends HTMLElement | null>(
  elements: Ref<T | T[]>,
  options?: useDistanceToElementsOptions,
) => {
  const { x, y } = useMouse();
  const { width, height } = useWindowSize();

  const threshold = options?.threshold ?? 0;

  const distances = computed(() =>
    (Array.isArray(elements.value) ? elements.value : [elements.value])?.map((element) => {
      if (element) {
        const rect = element.getBoundingClientRect();

        const elementX = rect.left + rect.width / 2;
        const elementY = rect.top + rect.height / 2;

        const mouseToElementDistance = computeDistance(x.value, y.value, elementX, elementY);

        if (threshold > 0) {
          return Math.max(0, (threshold - mouseToElementDistance) / threshold);
        } else {
          // Determine farthest window corner from element
          const cornerX = elementX < width.value / 2 ? width.value : 0;
          const cornerY = elementY < height.value / 2 ? height.value : 0;

          const cornerToElementDistance = computeDistance(cornerX, cornerY, elementX, elementY);

          return (cornerToElementDistance - mouseToElementDistance) / cornerToElementDistance;
        }
      }

      return 0;
    }),
  );

  return {
    distances,
  };
};
