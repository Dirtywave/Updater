import type { PhysicalPosition } from '@tauri-apps/api/dpi';
import { getCurrentWebview } from '@tauri-apps/api/webview';
import type { Ref } from 'vue';
import { computed, ref } from 'vue';

const filterToHexFiles = (paths: Set<string>): string[] =>
  [...paths.values()].filter((path) => path.endsWith('.hex'));

type FirmwarePath = {
  name: string;
  path: string;
};

const processPath = (path: string): FirmwarePath => ({
  name: path.split(/[/\\]/).at(-1) ?? path,
  path,
});

const processPaths = (paths: string[]) => paths.map(processPath);

const filterAndProcessPaths = (paths: Set<string>): FirmwarePath[] =>
  processPaths(filterToHexFiles(paths));

const useFilteredAndProcessedPaths = (paths: Ref<Set<string>>) =>
  computed(() => filterAndProcessPaths(paths.value));

const dragDropListenerRegistered = ref(false);

const dragDropPaths = ref<Set<string>>(new Set());
const dragDropMaybePaths = ref<Set<string>>(new Set());

const maybePaths = useFilteredAndProcessedPaths(dragDropMaybePaths);
const paths = useFilteredAndProcessedPaths(dragDropPaths);

const dragDropState = ref<'dragging' | 'dropped' | 'idle'>('idle');
// const dragDropPathsValid = computed(() => dragDropPaths.value.every((path) => path.endsWith('.hex')));

const dragDropPosition = ref<PhysicalPosition>();

const clearDragDropPaths = () => {
  dragDropPaths.value.clear();
};

export const useDragDropListener = () => {
  if (!dragDropListenerRegistered.value) {
    dragDropListenerRegistered.value = true;

    getCurrentWebview()
      .onDragDropEvent(({ payload }) => {
        switch (payload.type) {
          case 'enter': {
            dragDropMaybePaths.value = new Set(payload.paths);
            dragDropPosition.value = payload.position;
            dragDropState.value = 'dragging';

            break;
          }

          case 'leave': {
            dragDropState.value = 'idle';

            dragDropMaybePaths.value.clear();

            break;
          }

          case 'drop': {
            dragDropPaths.value = new Set(payload.paths);
            dragDropPosition.value = payload.position;
            dragDropState.value = 'dropped';

            dragDropMaybePaths.value.clear();

            break;
          }
        }
      })
      .then(
        () => void 0,
        () => void 0,
      );
  }

  return {
    clearDragDropPaths,
    maybePaths,
    paths,
    position: dragDropPosition,
    state: dragDropState,
  };
};
