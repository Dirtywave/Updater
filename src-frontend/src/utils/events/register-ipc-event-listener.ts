import type { Event } from '@tauri-apps/api/event';
import { listen } from '@tauri-apps/api/event';
import type { IpcEvent, IpcEventPayloads } from 'src/types';

export const registerIpcEventListener = async <E extends IpcEvent, P = IpcEventPayloads[E]>(
  event: E,
  callback: (payload: P, event: Event<P>) => void,
) => await listen<P>(event, (_event) => callback(_event.payload, _event));
