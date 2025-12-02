<script lang="ts" setup>
import { useInstallationStore } from 'stores/installation';
import { bracketsDirective } from 'directives/hover-brackets';
import { computed, onMounted, useTemplateRef } from 'vue';
import { storeToRefs } from 'pinia';
import UpdateLog from 'components/UpdateLog.vue';
import { matArrowDropDown, matArrowDropUp } from '@quasar/extras/material-icons';
import type { QExpansionItem } from 'quasar';

const { downloadStatus, updateLog, updateState } = storeToRefs(useInstallationStore());

const isFlashing = computed(
  () => downloadStatus.value.state !== 'Stopped' || updateState.value !== 'Stopped',
);

const updateLogExpansionItemRef = useTemplateRef<QExpansionItem>('updateLogExpansionItem');

const updateLogRef = useTemplateRef('updateLogRef');

// Have to do a weird thing here where the directive is programmatically applied since
// there is no direct access to the focusable element (the .q-item) within the expansion item.
onMounted(() => {
  const maybeElement = updateLogExpansionItemRef.value?.$el as HTMLElement | null | undefined;

  const qItem: HTMLElement | null | undefined = maybeElement?.querySelector('.q-item');

  if (qItem) {
    bracketsDirective.mounted(qItem, {
      instance: null,
      value: {
        // focusOnly: true, // TODO: Get the hover-only state working on parent
        offset: 1,
        onFocusChange: (focused: boolean) => {
          maybeElement?.classList.toggle('focused', focused);
        },
        // size: '0.3rem',
      },
      modifiers: {},
      oldValue: null,
      dir: bracketsDirective,
    });
  }
});
</script>

<template>
  <q-expansion-item
    ref="updateLogExpansionItem"
    @after-show="updateLogRef?.scrollToBottom()"
    :expand-icon="matArrowDropDown"
    :expanded-icon="matArrowDropUp"
    :expand-separator="false"
    header-style="min-height: unset"
    label="Update Log"
    dense
    dense-toggle
    :class="[{ active: isFlashing }, 'bg-dark flashing-log-container no-quasar-focus-helper']"
  >
    <template #header>
      <div
        class="col-shrink full-width items-center justify-start q-py-none row text-caption text-dirty-white"
        style="height: 1em"
      >
        <div class="full-width items-center q-gutter-x-xs row title">
          <div class="full-width row q-gutter-x-xs">
            <div class="col-auto">Update Log</div>

            <q-separator vertical class="q-my-xs" />

            <div class="col ellipsis text-monospace text-white" style="font-size: 0.8em">
              {{ updateLog[updateLog.length - 1]?.line }}
            </div>
          </div>
        </div>
      </div>
    </template>

    <div ref="logArea" class="column tycmd-log-area wrap">
      <div class="border invisible" />

      <div class="col relative-position">
        <UpdateLog ref="updateLogRef" :entries="updateLog" />
      </div>

      <div class="border invisible" />
    </div>
  </q-expansion-item>
</template>

<style lang="scss" scoped>
@use 'sass:map';

.flashing-log-container {
  :deep(.q-item) {
    padding-left: 0;
    padding-right: 0;

    .q-icon {
      font-size: 1.25em;
    }

    .q-item__section--side {
      padding-right: 0.5em;
    }
  }

  .title {
    padding-left: 0.25em;
  }
}

.tycmd-log-area {
  --log-height: 8.25rem;
  --log-width: 255px;
  flex-basis: var(--log-height);
  max-height: var(--log-height);
  min-height: var(--log-height);
}
</style>
