import { acceptHMRUpdate, defineStore } from 'pinia';

type EventStoreState = {
  deviceStateUpdateEventCount: number;
};

type EventStoreKey = 'event';

export const useEventStore = defineStore<
  EventStoreKey,
  EventStoreState,
  { [k: string]: never },
  { [k: string]: never }
>('event', {
  state: () => ({
    deviceStateUpdateEventCount: 0,
  }),
  getters: {},
  actions: {},
  tauri: {
    save: false,
    saveOnChange: false,
    sync: false,
  },
});

if (import.meta.hot) {
  import.meta.hot.accept(acceptHMRUpdate(useEventStore, import.meta.hot));
}
