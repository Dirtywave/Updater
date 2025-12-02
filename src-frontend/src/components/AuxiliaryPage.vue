<script lang="ts" setup>
import { symOutlinedCloseSmall } from '@quasar/extras/material-symbols-outlined';
import ChromeBar from 'components/ChromeBar.vue';
import { QBtn } from 'quasar';

defineProps<{ title: string }>();

const emit = defineEmits<{
  close: [];
}>();
</script>

<template>
  <section ref="section" class="column full-height">
    <ChromeBar class="col-auto justify-between q-pl-sm row">
      <!-- <div class="no-pointer-events non-selectable text-caption title">{{ title }}</div> -->
      <div class="text-dirty-white text-subtitle2 text-weight-medium title">{{ title }}</div>

      <div class="close-button-container q-ma-xs">
        <q-btn
          v-brackets
          ref="closeButton"
          @click="emit('close')"
          :aria-label="`close ${title} page`"
          :icon="symOutlinedCloseSmall"
          color="dirty-white"
          size="sm"
          dense
          flat
          class="no-quasar-focus-helper"
        />
      </div>
    </ChromeBar>

    <div class="bg-aero-lg col q-pr-sm">
      <slot />
    </div>
  </section>
</template>

<style lang="scss" scoped>
.close-button-container {
  padding-right: 0.1em;
}

.title {
  font-size: 0.875rem;
}
</style>
