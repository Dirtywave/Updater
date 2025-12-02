<script setup lang="ts">
import { computed, ref } from 'vue';
import { storeToRefs } from 'pinia';
import { useSerialPortInfoStore } from 'src/stores/serial-port-info';
import { useInstallationStore } from 'src/stores/installation';
import ChromeBar from 'components/ChromeBar.vue';
import SelectedVersion from 'components/SelectedVersion.vue';
import UpdateFirmwareButton from 'components/UpdateFirmwareButton.vue';
import LoadingSpinner from 'components/LoadingSpinner.vue';

const emit = defineEmits<{
  flash: [];
}>();

const { downloadStatus, installationStatus, selectedFirmware, updateState } =
  storeToRefs(useInstallationStore());

const { device, deviceConnected } = storeToRefs(useSerialPortInfoStore());

const hideUpdateFirmwareButton = ref(false);

const version = computed(() => selectedFirmware.value?.version ?? '------');

const disableButtons = computed(
  () =>
    !deviceConnected.value ||
    !device.value ||
    ['miss', 'remove'].includes(device.value.ty_cmd_info.action) ||
    !selectedFirmware.value ||
    installationStatus.value === 'updating',
);

const statusText = computed(() => {
  if (downloadStatus.value.state !== 'Stopped') {
    switch (downloadStatus.value.state) {
      case 'Complete': {
        return 'Download complete';
      }

      case 'Downloading': {
        return 'Downloading';
      }

      case 'Error': {
        return 'Download error';
      }

      case 'Starting': {
        return 'Download start';
      }
    }
  }

  switch (updateState.value) {
    case 'Error': {
      return 'Flashing error';
    }

    case 'Finalizing': {
      return 'Finalizing';
    }

    case 'Starting': {
      return 'Flashing starting';
    }

    case 'Updating': {
      return 'Flashing';
    }
  }

  return '';
});

const onUpdateFirmwareButtonClick = () => {
  hideUpdateFirmwareButton.value = true;

  emit('flash');
};
</script>

<template>
  <ChromeBar
    position="bottom"
    shadow-color="#222222"
    :class="[{ 'overflow-hidden': disableButtons }, 'relative-position']"
  >
    <div class="full-width row items-center justify-between q-pl-sm">
      <div class="no-pointer-events non-selectable text-caption">
        <div v-if="downloadStatus.state !== 'Stopped'">{{ statusText }}</div>

        <div v-else class="item-center q-gutter-x-xs row">
          <div>Selected:</div>

          <div>
            <SelectedVersion :selected-version="version" class="col-auto self-end" />
          </div>
        </div>
      </div>

      <div class="q-gutter-x-xs q-mr-xs row self-stretch">
        <q-separator vertical />

        <div class="relative-position update-firmware-button-container">
          <Transition
            @after-leave="hideUpdateFirmwareButton = false"
            appear
            enter-active-class="animated fadeIn"
            leave-active-class="animated fadeOut"
          >
            <div
              v-if="installationStatus === 'updating'"
              class="absolute-center color-cycle items-center justify-center row"
            >
              <LoadingSpinner size="1em" />
            </div>
          </Transition>

          <UpdateFirmwareButton
            @update="onUpdateFirmwareButtonClick"
            :disable="disableButtons"
            :hide="hideUpdateFirmwareButton"
          />
        </div>
      </div>
    </div>
  </ChromeBar>
</template>

<style lang="scss" scoped>
// @use '../css/quasar.variables.scss' as *;
// @use 'sass:color';

.pulse-shadow {
  // animation: pulse-shadow 3s infinite;
}

.pulse-shadow-negative {
  // animation: pulse-shadow-negative 3s infinite;
}

.pulse-shadow-negative-once {
  animation: pulse-shadow-negative 3s 1;
}

// .animated.fadeOut .pulse-shadow-negative {
//   animation: none !important;
// }

:deep(.animated.fadeOut .pulse-shadow-negative) {
  animation-play-state: paused;
}

// @debug $primary;

// $colors: (
//   primary: $primary,
//   secondary: $secondary,
//   accent: $accent,
//   negative: $negative,
//   positive: $positive
// );

// @each $name, $color in $colors {
//   @keyframes pulse-shadow-#{$name} {
//     0% {
//       filter: drop-shadow(0 0 0px #{$color}) drop-shadow(0 0 0px #{$color}) drop-shadow(0 0 0px #{$color});
//     }

//     50% {
//       filter: drop-shadow(0 0 24px rgba(#{color.channel($color, "red", $space: rgb)},
//           #{color.channel($color, "green", $space: rgb)},
//           #{color.channel($color, "blue", $space: rgb)},
//           0.1)) drop-shadow(0 0 24px rgba(#{color.channel($color, "red", $space: rgb)},
//           #{color.channel($color, "green", $space: rgb)},
//           #{color.channel($color, "blue", $space: rgb)},
//           0.1)) drop-shadow(0 0 24px rgba(#{color.channel($color, "red", $space: rgb)},
//           #{color.channel($color, "green", $space: rgb)},
//           #{color.channel($color, "blue", $space: rgb)},
//           0.5));
//     }

//     100% {
//       filter: drop-shadow(0 0 6px rgba(#{color.channel($color, "red", $space: rgb)},
//           #{color.channel($color, "green", $space: rgb)},
//           #{color.channel($color, "blue", $space: rgb)},
//           0)) drop-shadow(0 0 12px rgba(#{color.channel($color, "red", $space: rgb)},
//           #{color.channel($color, "green", $space: rgb)},
//           #{color.channel($color, "blue", $space: rgb)},
//           0)) drop-shadow(0 0 24px rgba(#{color.channel($color, "red", $space: rgb)},
//           #{color.channel($color, "green", $space: rgb)},
//           #{color.channel($color, "blue", $space: rgb)},
//           0));
//     }
//   }

//   .pulse-shadow-#{$name} {
//     animation: pulse-shadow-#{$name} 3s infinite;
//   }
// }

// Usage: <div class="pulse-shadow-primary">...</div>

@keyframes pulse-shadow {
  0% {
    filter: drop-shadow(0 0 0px var(--q-primary)) drop-shadow(0 0 0px var(--q-primary))
      drop-shadow(0 0 0px var(--q-primary));
  }

  50% {
    filter: drop-shadow(0 0 24px rgba(0, 229, 255, 0.1))
      drop-shadow(0 0 24px rgba(0, 229, 255, 0.1)) drop-shadow(0 0 24px rgba(0, 229, 255, 0.5));
  }

  100% {
    filter: drop-shadow(0 0 6px rgba(0, 229, 255, 0)) drop-shadow(0 0 12px rgba(0, 229, 255, 0))
      drop-shadow(0 0 24px rgba(0, 229, 255, 0));
  }
}

@keyframes pulse-shadow-negative {
  0% {
    filter: drop-shadow(0 0 0px var(--q-negative)) drop-shadow(0 0 0px var(--q-negative))
      drop-shadow(0 0 0px var(--q-negative));
  }

  50% {
    filter: drop-shadow(0 0 24px rgba(233, 30, 99, 0.1))
      drop-shadow(0 0 24px rgba(233, 30, 99, 0.5)) drop-shadow(0 0 24px rgba(233, 30, 99, 0.1));
  }

  100% {
    filter: drop-shadow(0 0 24px rgba(233, 30, 99, 0)) drop-shadow(0 0 12px rgba(233, 30, 99, 0))
      drop-shadow(0 0 6px rgba(233, 30, 99, 0));
  }
}

// .shadow-color {
//   --chrome-bar-shadow-color-rgb: #{color.channel($shadow-color, "red", $space: rgb)},
//   #{color.channel($shadow-color, "green", $space: rgb)},
//   #{color.channel($shadow-color, "blue", $space: rgb)};
// }

.selected-version-container {
  --width: 14ch;
  max-width: var(--width);
  min-width: var(--width);
  width: var(--width);
}
</style>
