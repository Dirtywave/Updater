<script lang="ts" setup>
import { computed } from 'vue';
import { colors } from 'quasar';

const { hexToRgb } = colors;

const { position = 'top', shadowColor } = defineProps<{
  position?: 'bottom' | 'top';
  shadowColor?: string;
}>();

const barStyle = computed(() => {
  if (!shadowColor) {
    return {};
  }

  const { r, g, b } = hexToRgb(shadowColor);

  return {
    '--chrome-bar-shadow-color-rgb': `${r}, ${g}, ${b}`,
  };
});
</script>

<template>
  <q-bar
    :class="[
      'bg-dark noise chrome-bar q-pl-none q-pr-none relative-position',
      position === 'top' ? 'shadow' : 'shadow-bottom',
      {
        'shadow-color': shadowColor === undefined,
      },
    ]"
    :style="barStyle"
  >
    <slot />
  </q-bar>
</template>

<style lang="scss" scoped>
@use '/node_modules/quasar/dist/quasar.css';
@use 'sass:color';

.shadow-color {
  --chrome-bar-shadow-color-rgb:
    #{color.channel($shadow-color, 'red', $space: rgb)},
    #{color.channel($shadow-color, 'green', $space: rgb)},
    #{color.channel($shadow-color, 'blue', $space: rgb)};
}

.shadow {
  border-bottom: 1px solid var(--q-dark-page);
  box-shadow:
    0px 3px 5px -3px rgba(var(--chrome-bar-shadow-color-rgb), 0.1),
    0px 6px 10px 1px rgba(var(--chrome-bar-shadow-color-rgb), 0.07),
    0px 1px 14px 2px rgba(var(--chrome-bar-shadow-color-rgb), 0.06);
}

.shadow-bottom {
  border-top: 1px solid var(--q-dark-page);
  color: var(--q-shadow-color);
  box-shadow:
    0px -3px 5px -3px rgba(var(--chrome-bar-shadow-color-rgb), 0.1),
    0px -6px 10px 1px rgba(var(--chrome-bar-shadow-color-rgb), 0.07),
    0px -1px 14px 2px rgba(var(--chrome-bar-shadow-color-rgb), 0.06);
}
</style>
