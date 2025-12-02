<script setup lang="ts">
import { computed, onMounted, ref, useTemplateRef } from 'vue';
import VersionListItem from 'components/VersionListItem.vue';
import { useInstallationStore } from 'src/stores/installation';
import { parseFirmwareFilename } from 'src/utils/filename-parsing';
import { usePickCustomFirmware } from 'src/composables/use-pick-custom-firmware';
import { useDeviceStateController } from 'src/composables/controllers/use-device-state-controller';
import { useFirmwareController } from 'src/composables/controllers/use-firmware-controller';
import { matFileOpen, matClear } from '@quasar/extras/material-icons';

const { cachedLocalFirmware, selectedFirmware } = useFirmwareController();

const { selectCustomPath } = useDeviceStateController();
const { localFilename } = useInstallationStore();

const pickCustomFirmware = usePickCustomFirmware();

const isLocalSelected = computed(() => selectedFirmware.value?.source === 'local');

const parsedFirmwareFilename = computed(() => {
  if (!cachedLocalFirmware.value) {
    return null;
  }

  return parseFirmwareFilename(
    cachedLocalFirmware.value.path.split('/').filter(Boolean).pop() ?? '',
  );
});

const selectLocalFirmware = async () => {
  if (cachedLocalFirmware.value) {
    await selectCustomPath(cachedLocalFirmware.value.path, cachedLocalFirmware.value.version);
  } else {
    await pickCustomFirmware();
  }
};

const clearLocalFirmware = () => {
  cachedLocalFirmware.value = null;

  if (selectedFirmware.value?.source === 'local') {
    selectedFirmware.value = null;
  }
};

const localFileSelectItemRef = useTemplateRef('localFileSelectItem');

/*
 *TODO: Make it so that this is focused for accessibility
 * (i.e. don't need to tab through every firmware ever to reach the local file select)
 */
onMounted(async () => (localFileSelectItemRef.value?.$el as HTMLElement)?.focus());
</script>

<template>
  <!-- q-pl-sm q-pr-lg -->
  <div class="item-container">
    <div :class="[{ 'no-selection': !cachedLocalFirmware?.path }, 'bg-dark-page']">
      <!-- :is-disabled="!cachedLocalFirmware?.path" -->
      <VersionListItem
        ref="localFileSelectItem"
        @main-action="selectLocalFirmware"
        :caption-label="
          cachedLocalFirmware
            ? (parsedFirmwareFilename?.model ?? 'MODEL:?')
            : 'Click to select local file'
        "
        :is-selected="isLocalSelected"
        :on-toggle-click="pickCustomFirmware"
        :selected-value="selectedFirmware?.path"
        :show-version-number="!!cachedLocalFirmware"
        :version="cachedLocalFirmware?.version ?? localFilename ?? '?'"
        icon-name="drive_folder_upload"
        primary-label="Local File"
        show-icon
        class="fit"
      >
        <template #main-action-aside>
          <div v-if="!cachedLocalFirmware" class="items-center q-pr-md row self-center">
            <q-icon :name="matFileOpen" color="dirty-white" size="0.875rem" />
          </div>
        </template>

        <template #aside>
          <div v-if="cachedLocalFirmware" class="full-height row self-center">
            <q-btn
              v-brackets="{ offset: 1 }"
              @click="clearLocalFirmware"
              :icon="matClear"
              size="sm"
              class="clear-firmware-selection-button full-height"
            />
            <!-- </div> -->
          </div>
        </template>
      </VersionListItem>
    </div>
  </div>
</template>

<style lang="scss" scoped>
.clear-firmware-selection-button:before {
  box-shadow: unset;
}

.item-container {
  --shadow-color-rgb: 200, 200, 200;
  // border: 1px solid transparent;
  // border-bottom: 1px solid transparent;
  // border-top: 1px solid rgba(255, 255, 255, 0.1);
  z-index: 9999;
  // transition: height 1.1s ease,
  //   0.1s ease padding-top,
  //   0.1s ease padding-bottom;
  // height: 100%;

  // height: 4.5em;

  &:hover.no-selection {
    // border-top-color: var(--q-primary);
    // box-shadow: 0px -2px 5px -3px rgba(var(--shadow-color-rgb), 0.1),
    //   0px -3px 10px 1px rgba(var(--shadow-color-rgb), 0.07),
    //   0px -1px 14px 2px rgba(var(--shadow-color-rgb), 0.06);
    // padding-top: 0.2em;
    // padding-bottom: 0.2em;
  }
}
</style>
