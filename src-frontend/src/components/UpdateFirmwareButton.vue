<script setup lang="ts">
import type { QBtnProps } from 'quasar';
import { ref } from 'vue';
import { matKeyboardDoubleArrowUp, matRemoveCircleOutline } from '@quasar/extras/material-icons';

const { disable, hide = false } = defineProps<
  { hide?: boolean } & Pick<QBtnProps, 'disable' | 'onClick'>
>();

const emit = defineEmits<{ update: [] }>();

const hovering = ref(false);
</script>

<template>
  <q-btn
    v-brackets="{ disabled: disable }"
    @click="emit('update')"
    @mouseenter="hovering = true"
    @mouseleave="hovering = false"
    :color="disable ? 'grey-4' : hovering ? 'primary' : 'secondary'"
    :disable="disable"
    size="sm"
    dense
    flat
    :class="[{ hide: hide, 'pulse-shadow': !disable }, 'update-firmware-button q-pl-sm']"
  >
    <div class="items-center no-wrap q-gutter-x-xs row">
      <div>Update</div>

      <q-icon v-if="disable" :name="matRemoveCircleOutline" style="transform: translateY(-1px)" />

      <q-icon v-else :name="matKeyboardDoubleArrowUp" />
    </div>
  </q-btn>
</template>

<style lang="scss" scoped>
.update-firmware-button {
  // https://css-irl.info/animating-underlines/
  // background:
  //   linear-gradient(to bottom, transparent, transparent),
  //   linear-gradient(to bottom, var(--q-primary), var(--q-primary));
  // background-size: 0.1em 100%, 0.1em 0;
  // background-position: 0 0, 0 0;
  // background-repeat: no-repeat;
  opacity: 1;
  // transition: 200ms ease background-size 500ms ease opacity;

  :deep(.q-icon) {
    filter: drop-shadow(0 0 4px transparent);
    transition:
      0.5s ease color,
      0.5s ease filter,
      0.25s ease transform;
  }

  // &.disabled {
  //   :deep(.q-icon) {
  //     opacity: 0;
  //   }
  // }

  &.hide {
    opacity: 0 !important;
  }

  &.q-hoverable:hover {
    :deep(.q-icon) {
      transform: translateY(-0.125em);
      transition:
        0.5s ease color,
        0.5s ease filter,
        0.25s ease transform !important;
    }
  }
}

.update-firmware-button.q-hoverable {
  &:hover {
    // background-size: 0.1em 0, 0.1em 100%;

    :deep(.q-focus-helper) {
      background: transparent;

      &::after {
        opacity: 0;
      }
    }

    :deep(.q-icon) {
      transition:
        0.5s ease color,
        0.5s ease filter;
      color: var(--q-primary);
      filter: drop-shadow(0 0 6px var(--q-primary));
    }
  }
}
</style>
