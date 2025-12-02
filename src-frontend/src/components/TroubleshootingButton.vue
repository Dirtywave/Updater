<script lang="ts" setup>
import { matHelp } from '@quasar/extras/material-icons';

import { useAuxiliaryViews } from 'src/composables/use-auxiliary-views';

const { showTroubleshooting, toggleTroubleshooting } = useAuxiliaryViews();
</script>

<template>
  <Transition
    appear
    enter-active-class="animated pulse-shadow-negative-once zoomIn"
    leave-active-class="animated fadeOut"
  >
    <div>
      <div
        :class="['relative-position', { 'pulse-shadow-negative': false /* !showTroubleshooting*/ }]"
      >
        <q-btn
          v-brackets
          @click="toggleTroubleshooting"
          :aria-label="`${showTroubleshooting ? 'hide' : 'show'} troubleshooting page`"
          :ripple="false"
          color="secondary"
          :icon="matHelp"
          id="toggle-troubleshooting-page"
          dense
          flat
          round
          class="troubleshooting-button"
        >
          <q-tooltip v-if="!showTroubleshooting">Troubleshooting & More</q-tooltip>
        </q-btn>
      </div>
    </div>
  </Transition>
</template>

<style lang="scss" scoped>
@use '/node_modules/quasar/dist/quasar.css';
@use 'src/css/colors.scss' as colors;

.pulse-shadow {
  // animation: pulse-shadow 3s infinite;
}

.pulse-shadow-negative {
  animation: pulse-shadow-negative 3s infinite;
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

.troubleshooting-button {
  :deep(.q-icon) {
    font-size: 1.25em;
  }
}
</style>
