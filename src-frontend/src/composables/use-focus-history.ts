import { ref } from 'vue';
import { useAuxiliaryViews } from 'composables/use-auxiliary-views';

const listenerAdded = ref(false);

const lastFocused = ref<HTMLElement | null>(null);

export const ignoredElementIds = ['toggle-troubleshooting-page'];

export const useFocusHistory = () => {
  const { showTroubleshooting } = useAuxiliaryViews();

  if (!listenerAdded.value) {
    window.addEventListener(
      'focus',
      (ev) => {
        if (showTroubleshooting.value) {
          return;
        }

        const target = ev.target;

        if (target instanceof HTMLElement) {
          if (!ignoredElementIds.includes(target.id)) {
            lastFocused.value = target;
          }
        }
      },
      { capture: true },
    );

    listenerAdded.value = true;
  }

  return {
    lastFocused,
  };
};
