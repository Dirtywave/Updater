<script lang="ts" setup>
import { getCssVar } from 'quasar';
import { useDistanceToElements } from 'src/composables';
import { colorTween } from 'src/utils';
import { computed, useTemplateRef } from 'vue';

const {
  asDiv = false,
  from = getCssVar('primary') ?? '#000',
  threshold = 400,
  to = getCssVar('accent') ?? '#FFF',
} = defineProps<{
  asDiv?: boolean;
  from?: string;
  threshold?: number;
  to?: string;
}>();

const textSpan = useTemplateRef<HTMLSpanElement>('text');

const { distances } = useDistanceToElements(textSpan, { threshold });

const color = computed(() =>
  colorTween({
    percentage: distances.value?.[0] ?? 0,
    from,
    to,
  }),
);
</script>

<template>
  <div v-if="asDiv" ref="text" class="text">
    <slot />
  </div>

  <span v-else ref="text" class="text">
    <slot />
  </span>
</template>

<style lang="scss" scoped>
.text {
  color: v-bind(color);
}
</style>
