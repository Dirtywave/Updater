<script setup lang="ts">
import { ref, watch, watchEffect } from 'vue';
import VersionListItem from 'components/VersionListItem.vue';
import { Notify } from 'quasar';
import ChangelogSectionContent from './ChangelogSectionContent.vue';
import { useFirmwareController } from 'src/composables/controllers/use-firmware-controller';
import { useDragDropListener } from 'src/composables/use-drag-drop-listener';
import ChangelogButton from 'components/ChangelogButton.vue';

const { selectedFirmware, selectVersion, entries, fetchFirmwareList } = useFirmwareController();

const { paths } = useDragDropListener();

const isSelected = (version: string | null, path?: string) =>
  selectedFirmware.value?.version === version &&
  (path ? selectedFirmware.value?.path === path : true);

try {
  await fetchFirmwareList();
} catch (e) {
  console.error('Failed to load firmware list', e);

  Notify.create({
    type: 'negative',
    message: 'Failed to load firmware list. You can still select a local file.',
  });
}

const expansionModel = ref<boolean[]>(Array(entries.value.length).fill(false));
const hideChangelogOnlyBadgeModel = ref<boolean[]>(Array(entries.value.length).fill(false));
const hideBracketsModel = ref<boolean[]>(Array(entries.value.length).fill(false));

const showLocalFirmwareSelection = ref(false);

const onMainAction = async (...args: Parameters<typeof selectVersion>) =>
  await selectVersion(...args);

watchEffect(() => {
  if (paths.value[0]) {
    showLocalFirmwareSelection.value = true;
  }
});

watch(entries, (list) => {
  expansionModel.value = Array(list.length).fill(false);
});
</script>

<template>
  <q-list tag="ol" class="firmware-list">
    <VersionListItem
      v-for="({ changelog, date, path, version }, i) in entries"
      :caption-label="date ?? '-'"
      :expanded="expansionModel[i]!"
      :hide-changelog-only-badge="hideChangelogOnlyBadgeModel[i]!"
      :is-disabled="!Boolean(path)"
      :is-selected="isSelected(version, path)"
      :key="version"
      :on-main-action="() => onMainAction({ path, source: 'remote', version })"
      :on-secondary-action="() => void 0"
      :selected-value="selectedFirmware?.path"
      :version="version"
      primary-label="Version"
      tag="li"
    >
      <template #aside="{ expanded }">
        <ChangelogButton
          v-if="changelog?.some(({ entries }) => entries.length > 0)"
          @click="expansionModel[i] = !expanded"
          @tooltip-visibility-change="hideChangelogOnlyBadgeModel[i] = $event"
          :expanded
          tooltip="Changelog"
        />
      </template>

      <template #content>
        <div
          v-if="expansionModel[i] && changelog?.some(({ entries }) => entries.length > 0)"
          class="q-pl-sm q-pr-xs"
        >
          <q-item-section v-for="section in changelog" :key="section.id">
            <q-item-label v-if="section.title" caption>
              {{ section.title }}
            </q-item-label>

            <ChangelogSectionContent :section="section" />
          </q-item-section>

          <div v-if="!isSelected(version, path)" class="absolute changelog-border" />
        </div>
      </template>
    </VersionListItem>
  </q-list>
</template>

<style lang="scss" scoped>
@use '/node_modules/quasar/dist/quasar.css';

ol {
  padding-inline-start: 0;
}

.changelog-border {
  --border-color: var(--q-secondary);
  border-left: 1px dashed var(--border-color);
  bottom: 1.5em; // 3em;
  left: 0; // 19.5px;
  top: 4em;
  transition: 0.25s ease all;
}

.firmware-list {
  & .firmware.q-item {
    border: 1px solid $dark-page;
    box-sizing: border-box;

    & .toggle {
      background: $dark-page;
      text-transform: unset;

      &.no-changelog {
        pointer-events: none;
      }

      &:hover {
        & :deep(.q-focus-helper) {
          opacity: 0;
        }
      }
    }

    &:hover {
      & .changelog-border {
        --border-color: var(--q-primary);
        transition: 0.25s ease all;
      }
    }
  }
}
</style>
