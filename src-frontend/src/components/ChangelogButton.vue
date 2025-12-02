<script lang="ts" setup>
import {
  matArrowDropDown,
  matArrowDropUp,
  matKeyboardArrowDown,
  matKeyboardArrowUp,
} from '@quasar/extras/material-icons';
import { computed } from 'vue';

const { expanded, version = 'version' } = defineProps<{
  expanded: boolean;
  version?: string;
  tooltip?: string;
}>();

defineOptions({
  inheritAttrs: false,
});

const emit = defineEmits<{
  'tooltip-visibility-change': [boolean];
}>();

// Base color only — hover/active handled in CSS
const textColor = computed(() => (expanded ? 'accent' : 'secondary'));
</script>

<template>
  <div class="changelog-button-container full-height relative-position">
    <q-btn
      v-bind="$attrs"
      v-brackets="{
        offset: 1,
      }"
      :aria-label="`${expanded ? 'close' : 'open'} ${version} changelog`"
      :ripple="false"
      :icon="expanded ? matArrowDropUp : matArrowDropDown"
      color="transparent"
      :text-color="textColor"
      unelevated
      class="changelog-button fit no-border-radius no-quasar-focus-helper q-pa-none"
    >
      <div class="absolute-full items-center justify-center row">
        <q-icon
          class="arrow"
          :name="expanded ? matKeyboardArrowUp : matKeyboardArrowDown"
          :class="[{ 'q-mb-sm': expanded, 'q-mt-sm': !expanded }]"
        />
      </div>

      <q-tooltip
        v-if="!expanded"
        @before-show="$emit('tooltip-visibility-change', true)"
        @before-hide="$emit('tooltip-visibility-change', false)"
        :delay="250"
        anchor="center left"
        self="center right"
      >
        {{ tooltip }}
      </q-tooltip>
    </q-btn>
  </div>
</template>

<style lang="scss" scoped>
/* ------------------------------------------- */
/* Arrow animation + color inheritance          */
/* ------------------------------------------- */
.arrow {
  opacity: 0;
  transform: translateX(1), translateY(calc(v-bind('expanded ? 1 : -1') * 0.125ch));
  transition:
    opacity 0.25s ease,
    transform 0.125s ease;
}

/* Force SVG to inherit text color */
.arrow :deep(svg) {
  fill: currentColor;
}

.changelog-button:hover {
  &:deep(svg) {
    fill: var(--q-primary);
  }

  .arrow {
    opacity: 1;
    transform: translateX(1), translateY(0);
  }
}

/* ------------------------------------------- */
/* Text + icon color logic (pure CSS)           */
/* ------------------------------------------- */
.changelog-button {
  width: 5ch;

  /* No transition by default — prevents weird fade on expand */
  transition: none;

  /* Idle */
  color: var(--q-secondary);

  &-container {
    aspect-ratio: 1;
  }

  /* Expanded (active) */
  &.glow-current-color {
    color: var(--q-accent);
  }

  /* Hover (only when NOT expanded) */
  &:not(.glow-current-color):hover {
    color: var(--q-primary);
    transition: color 0.15s ease; /* hover only */
  }
}
</style>
