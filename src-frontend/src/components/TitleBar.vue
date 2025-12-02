<script lang="ts" setup>
import { matClose } from '@quasar/extras/material-icons';

import ChromeBar from 'components/ChromeBar.vue';
import TroubleshootingButton from 'components/TroubleshootingButton.vue';
import { matHelp } from '@quasar/extras/material-icons';

import { useAuxiliaryViews } from 'src/composables/use-auxiliary-views';

const { showTroubleshooting, toggleTroubleshooting } = useAuxiliaryViews();

defineProps<{ settingsOpen: boolean }>();

const emit = defineEmits<{
  close: [void];
}>();
</script>

<template>
  <ChromeBar>
    <div class="row q-gutter-xs">
      <img src="~assets/icon-transparent-background.svg" height="24px" width="24px" />

      <div class="text-dirty-white text-subtitle2 text-weight-medium title">Dirtywave Updater</div>

      <div data-tauri-drag-region class="absolute-full" />
    </div>

    <q-space />

    <div class="items-center justify-center q-mr-xs row">
      <div class="items-center justify-center row">
        <!-- <TroubleshootingButton class="no-quasar-focus-helper" /> -->
        <q-btn
          v-brackets
          @click="toggleTroubleshooting"
          :aria-label="`${showTroubleshooting ? 'hide' : 'show'} troubleshooting page`"
          :ripple="false"
          color="secondary"
          id="toggle-troubleshooting-page"
          dense
          flat
          round
          class="no-quasar-focus-helper square troubleshooting-button"
        >
          <div style="padding: 1px">
            <q-icon :name="matHelp" />
          </div>
        </q-btn>
      </div>

      <!-- class="q-ml-sm q-mr-xs" -->
      <div class="q-mx-xs">
        <q-separator vertical class="q-py-sm" />
      </div>

      <div class="items-center justify-center row">
        <q-btn
          v-brackets
          @click="emit('close')"
          aria-label="close Dirtywave Updater"
          :icon="matClose"
          ref="closeButton"
          text-color="negative"
          dense
          flat
          class="close-button no-quasar-focus-helper q-px-xs square"
        >
        </q-btn>
      </div>
    </div>
  </ChromeBar>
</template>

<style lang="scss" scoped>
@use '/node_modules/quasar/dist/quasar.css';
@use 'src/css/colors.scss' as colors;

.close-button {
  height: 1.625rem;
  width: 1.625rem;
}

.settings-button-update-hint {
  animation: pingPongOpacity 4.5s ease-in infinite;
  left: 3.5px;
  top: -2.5px;

  @keyframes pingPongOpacity {
    0% {
      opacity: 0;
    }

    50% {
      opacity: 1;
    }

    100% {
      opacity: 0;
    }
  }
}

.title {
  // Visually centers title with DW logo
  transform: translateY(1px);
}

.troubleshooting-button {
  :deep(.q-icon) {
    font-size: 1.25em;
  }
}
</style>
