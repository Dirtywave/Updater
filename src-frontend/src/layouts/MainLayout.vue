<script setup lang="ts">
import { nextTick, onMounted, ref, watch } from 'vue';
import { emitTo } from '@tauri-apps/api/event';
import { getCurrentWindow } from '@tauri-apps/api/window';
import { getVersion } from '@tauri-apps/api/app';
import { storeToRefs } from 'pinia';
import { useAuxiliaryViews } from 'src/composables/use-auxiliary-views';
import { useInstallationStore } from 'src/stores/installation';
import { useSerialPortInfoStore } from 'src/stores/serial-port-info';
import DragDropIndicator from 'src/components/DragDropIndicator.vue';
import FlashingSection from 'components/FlashingSection.vue';
import TitleBar from 'components/TitleBar.vue';
import TroubleshootingPage from 'src/components/TroubleshootingPage.vue';
import type { Window } from '@tauri-apps/api/window';
import { useFocusHistory } from 'composables/use-focus-history';
import UpdateLogExpansionItem from 'components/UpdateLogExpansionItem.vue';

const { lastFocused } = useFocusHistory();

const { showSettings, showTroubleshooting, toggleTroubleshooting } = useAuxiliaryViews();

watch(showTroubleshooting, async () => {
  if (!showTroubleshooting.value) {
    await nextTick(() => lastFocused.value?.focus());
  }
});

const { updateLog, updateState } = storeToRefs(useInstallationStore());

const { deviceConnected } = storeToRefs(useSerialPortInfoStore());
const appWindow = ref<Window | null>(null);
const version = ref<string>('');

onMounted(async () => {
  appWindow.value = getCurrentWindow();

  version.value = await getVersion();
});

const closeWindow = () => appWindow.value?.close();

const downloadFirmware = async () => {
  updateLog.value.push({ line: 'Downloading...', state: updateState.value });

  if (deviceConnected.value) {
    await emitTo('main', 'start-firmware-download', {});
  }
};
</script>

<template>
  <div class="application-container">
    <q-layout view="lHh Lpr lFf" class="layout">
      <q-header v-if="true" class="bg-dark non-selectable q-pa-none text-primary">
        <TitleBar @close="closeWindow" :settings-open="showSettings" />
      </q-header>

      <q-page-container class="overflow-visible">
        <router-view :inert="showTroubleshooting" />

        <!-- Hardcoded padding comes from needing to counteract the padding at top of .q-page-container that Quasar applies via style  -->
        <div class="absolute-full no-pointer-events z-top" id="overlay" style="padding-top: 32px" />
      </q-page-container>

      <q-footer class="bg-transparent">
        <Transition
          enter-active-class="animated slideInUp faster"
          leave-active-class="animated slideOutDown faster"
        >
          <div
            v-if="showSettings || showTroubleshooting"
            class="fixed-full z-top"
            style="bottom: 32px; top: 32px"
          >
            <TroubleshootingPage v-show="showTroubleshooting" @close="toggleTroubleshooting" />
          </div>
        </Transition>

        <Transition appear enter-active-class="animated slideInUp">
          <UpdateLogExpansionItem v-show="updateLog.length > 0" />
        </Transition>

        <FlashingSection @flash="downloadFirmware" class="z-top" />
      </q-footer>

      <DragDropIndicator />
    </q-layout>

    <div class="absolute-full border no-pointer-events z-top" />
  </div>
</template>

<style lang="scss" scoped>
.application-container {
  box-sizing: border-box;
  border: 1px solid transparent;
}

.border {
  border: 1px solid var(--q-dark-page);
}
</style>
