import { createPinia } from 'pinia';
import { TauriPluginPinia } from '@tauri-store/pinia';

export const initStore = () => {
  const pinia = createPinia();

  pinia.use(TauriPluginPinia());

  return pinia;
};

export default initStore;
