import type { App } from 'vue';
import type { Pinia } from 'pinia';
import type { Router } from 'vue-router';

export type BootCallbackParams = {
  app: App;
  router: Router;
  store: Pinia;
};

export type BootCallback = (params: BootCallbackParams) => void | Promise<void>;

export const defineBoot = (callback: BootCallback): BootCallback => callback;
