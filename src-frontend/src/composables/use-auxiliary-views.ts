import { onKeyStroke } from '@vueuse/core';
import { ref } from 'vue';

const showSettings = ref(false);

const showTroubleshooting = ref(false);

export const useAuxiliaryViews = () => {
  onKeyStroke('Escape', () => {
    if (showSettings.value) {
      showSettings.value = false;
    }

    if (showTroubleshooting.value) {
      showTroubleshooting.value = false;
    }
  });

  return {
    showSettings,
    showTroubleshooting,
    toggleSettings: () => {
      console.log('b4 showSettings set');
      showSettings.value = !showSettings.value;
      console.log('after showSettings set');

      if (showTroubleshooting.value) {
        console.log('b4 showTroubleshooting set');
        showTroubleshooting.value = false;
        console.log('after showTroubleshooting set');
      }
    },
    toggleTroubleshooting: () => {
      console.log('b4 showTroubleshooting set');
      showTroubleshooting.value = !showTroubleshooting.value;
      console.log('after showTroubleshooting set');

      if (showSettings.value) {
        console.log('b4 showSettings set');
        showSettings.value = false;
        console.log('after showSettings set');
      }
    },
  };
};
