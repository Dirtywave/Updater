<template>
  <span class="version-number" ref="version">
    {{ version }}
  </span>
</template>

<script lang="ts" setup>
import { computed } from 'vue';

// import { getCssVar } from 'quasar';
// import { useDistanceToElements } from 'src/composables';
// import { colorTween } from 'src/utils';
// import { computed, useTemplateRef } from 'vue';

const { color: defaultColor = 'var(--q-secondary)', selected } = defineProps<{
  color?: string | undefined;
  selected?: boolean;
  version: string;
}>();

const color = computed(() => (selected ? 'var(--q-primary)' : defaultColor));
// const versionSpan = useTemplateRef<HTMLSpanElement>('version');

// const { distances } = useDistanceToElements(versionSpan, { threshold: 400 });

// const color = computed(() => colorTween({
//   percentage: distances.value?.[0] ?? 0,
//   from: getCssVar('primary') ?? '#000',
//   to: getCssVar('secondary') ?? '#FFF',
// }));
</script>

<style lang="scss" scoped>
.version-number {
  color: v-bind('color');
  // transition: color 0.2s;

  // &:hover {
  //   color: var(--q-accent);
  // }
}
</style>
