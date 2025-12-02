<script setup lang="ts">
const {
  bracketSize = '0.5rem',
  hovering = false,
  itemDisabled = false,
} = defineProps<{
  bracketSize?: string;
  hovering?: boolean;
  itemDisabled?: boolean;
  selected: boolean;
}>();
</script>

<template>
  <transition name="hover">
    <div
      v-if="hovering || selected"
      :class="[
        'absolute-full brackets no-pointer-events',
        { hovering, 'item-disabled': itemDisabled, selected },
      ]"
    >
      <div class="bracket-helper fit" />
    </div>
  </transition>
</template>

<style lang="scss" scoped>
@use '/node_modules/quasar/dist/quasar.css';
@use 'src/css/colors.scss' as colors;

@mixin bracket-base {
  content: '';
  position: absolute;
  width: var(--bracket-size);
  height: var(--bracket-size);
  border: 1px solid var(--bracket-color);
  border-color: var(--bracket-color) !important;
}

.brackets {
  --transition-duration: 0s;
  z-index: 1;
  filter: drop-shadow(0 0 4px var(--bracket-color));

  &.hovering:not(.selected) {
    --bracket-color: var(--q-primary);
    --bracket-offset: -1px;
    --bracket-size: v-bind('bracketSize');

    &::before,
    &::after {
      @include bracket-base;
      pointer-events: none;
    }

    &::before {
      top: var(--bracket-offset);
      left: var(--bracket-offset);
      border-width: 1px 0 0 1px;
    }

    &::after {
      bottom: var(--bracket-offset);
      right: var(--bracket-offset);
      border-width: 0 1px 1px 0;
    }

    &.item-disabled {
      --bracket-color: #{colors.$text-disabled};
    }

    .bracket-helper {
      &::before,
      &::after {
        @include bracket-base;
      }

      &::before {
        top: var(--bracket-offset);
        right: var(--bracket-offset);
        border-width: 1px 1px 0 0;
      }

      &::after {
        bottom: var(--bracket-offset);
        left: var(--bracket-offset);
        border-width: 0 0 1px 1px;
      }
    }
  }

  &.selected {
    --transition-duration: 0.25s;
    --bracket-color: var(--q-accent) !important;

    border: 1px solid var(--bracket-color);
    transition:
      var(--transition-duration) border-color ease,
      var(--transition-duration) filter ease;

    .bracket-helper {
      border-color: transparent;
      filter: none;
    }

    &.hovering {
      transition: none;

      --bracket-color: var(--q-primary) !important;

      .bracket-helper {
        filter: drop-shadow(0 0 4px var(--q-primary));
      }
    }
  }
}

.hover {
  &-leave-to {
    opacity: 0;
    transition: var(--transition-duration) opacity ease;
  }
}
</style>
