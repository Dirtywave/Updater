import { acceptHMRUpdate, defineStore } from 'pinia';
import type { Device } from 'src/types';

type SerialPortInfoStoreState = {
  device: Device | null;
};

export const useSerialPortInfoStore = defineStore<
  'serial-port-info',
  SerialPortInfoStoreState,
  {
    deviceConnected: (state: SerialPortInfoStoreState) => boolean;
  }
>('serial-port-info', {
  state: () => ({
    device: null,
    selectedDeviceTag: null,
  }),
  getters: {
    deviceConnected: (state) => state.device !== null,
  },
  actions: {},
  tauri: {
    save: false,
    saveOnChange: false,
    sync: false,
  },
});

if (import.meta.hot) {
  import.meta.hot.accept(acceptHMRUpdate(useSerialPortInfoStore, import.meta.hot));
}
