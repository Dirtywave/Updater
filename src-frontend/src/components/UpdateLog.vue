<script setup lang="ts">
import { computed, nextTick, ref, useTemplateRef, watch } from 'vue';
import { QScrollArea } from 'quasar';
import type { LogEntry } from 'src/types/installation';

const { entries } = defineProps<{
  entries: LogEntry[];
}>();

console.log('provided entries:');
console.log(entries);

const updateLogRef = useTemplateRef<QScrollArea>('updateLog');

const updateLogStuck = ref(true);

const hasEntries = computed(() => entries.some(({ line }) => line));

const onUpdateLogScroll: QScrollArea['onScroll'] = ({ verticalPercentage }) =>
  (updateLogStuck.value = verticalPercentage === 1);

const scrollToBottom = () =>
  updateLogRef.value?.setScrollPosition(
    'vertical',
    updateLogRef.value?.getScroll().verticalSize,
    0,
  );

watch(
  () => entries,
  async () => {
    if (updateLogRef.value && updateLogStuck.value) {
      await nextTick(scrollToBottom);
    }
  },
  { deep: true },
);

watch(hasEntries, async (value, oldValue) => {
  if (!oldValue && value) {
    await nextTick(scrollToBottom);
  }
});

defineExpose({
  scrollToBottom,
});
</script>

<template>
  <!-- <div class="fit relative-position"> -->

  <q-scroll-area
    v-if="hasEntries"
    ref="updateLog"
    @scroll="onUpdateLogScroll"
    :horizontal-offset="[0, 8]"
    :vertical-offset="[8, 8]"
    :class="[{ invisible: !hasEntries }, 'absolute-full q-ma-none q-pl-xs q-py-xs update-log']"
  >
    <div class="column">
      <ol class="fit update-log-entries-container">
        <li class="non-selectable q-space spacer" />

        <li
          v-for="({ line, state }, i) in entries"
          :key="`${line}${i}`"
          :class="[{ 'text-negative': state === 'Error' }, 'col-auto']"
        >
          <!-- If line is an empty string, the <li /> has no height so the
               non-breaking space is added to ensure vertical space is taken up -->
          {{ line }}&nbsp;
        </li>
      </ol>
    </div>
  </q-scroll-area>

  <div v-else class="update-log" />
</template>

<style lang="scss" scoped>
.update-log {
  font-family: monospace;
  font-size: 0.75em;
  // min-height: var(--log-height);
  // min-width: var(--log-width);

  &-entries-container {
    //   min-height: var(--log-height);

    & .spacer {
      height: var(--log-height); // calc(var(--log-height) - 3.25rem);
      // min-height: calc(var(--log-height) - 1em);
    }
  }

  &-label {
    left: 0.5em;
    top: -0.75em;
  }

  & ol {
    list-style: none;
    margin-block-end: 0;
    margin-block-start: 0;
    padding-inline-start: 0;
  }

  &::after {
    background: linear-gradient(
      0deg,
      rgba($dark-page, 0) 0%,
      rgba($dark-page, 0.33) 33.33%,
      rgba($dark-page, 0.666) 66.66%,
      $dark-page 100%
    );

    bottom: 0;
    content: '';
    left: 0;
    pointer-events: none;
    position: absolute;
    right: 0;
    top: 0;
  }
}
</style>
