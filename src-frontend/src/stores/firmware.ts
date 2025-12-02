import { acceptHMRUpdate, defineStore } from 'pinia';
import type { Firmware } from 'src/types';

type FirmwareStoreState = {
  firmwares: Firmware[];
};

type FirmwareStoreKey = 'firmware';

export const useFirmwareStore = defineStore<
  FirmwareStoreKey,
  FirmwareStoreState,
  { entries: (state: FirmwareStoreState) => Firmware[] },
  { [k: string]: never }
>('firmware', {
  state: () => ({
    firmwares: [],
  }),
  getters: {
    entries: (state) =>
      state.firmwares.filter(
        ({ changelog, path }) => Boolean(changelog?.[0]?.entries?.length) || Boolean(path),
      ),
  },

  actions: {},
  tauri: {
    saveOnChange: true,
  },
});

if (import.meta.hot) {
  import.meta.hot.accept(acceptHMRUpdate(useFirmwareStore, import.meta.hot));
}
