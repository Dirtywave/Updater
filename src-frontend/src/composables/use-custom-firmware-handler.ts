import { useDragDropListener } from 'src/composables/use-drag-drop-listener';
import { watchEffect } from 'vue';

export const useCustomFirmwareHandler = () => {
  const { paths } = useDragDropListener();

  watchEffect(() => {
    if (paths.value.length > 0) {
      // TODO: emit custom firmware event
    }
  });
};
