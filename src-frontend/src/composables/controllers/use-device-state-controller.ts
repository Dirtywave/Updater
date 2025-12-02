import { registerIpcEventListener } from 'src/utils';
import { useInstallationStore } from 'src/stores/installation';
import { useSerialPortInfoStore } from 'src/stores/serial-port-info';
import type { DeviceStateUpdate } from 'src/types';
import type { LogEntry } from 'src/types/installation';
import { parseFirmwareFilename } from 'src/utils/filename-parsing';
import { useEventStore } from 'src/stores/event';
import { storeToRefs } from 'pinia';

let unlisten: null | (() => void) = null;

let listenersStarted = false;

export const useDeviceStateController = () => {
  const installationStore = useInstallationStore();

  const { deviceStateUpdateEventCount } = storeToRefs(useEventStore());

  const serialStore = useSerialPortInfoStore();

  function handleDeviceStateUpdate(payload: DeviceStateUpdate) {
    console.log('In device-state-update event handler, with payload:');
    console.log(JSON.stringify(payload, null, 2));

    deviceStateUpdateEventCount.value += 1;

    console.log('handleDeviceStateUpdate:');
    console.log(JSON.stringify(payload, null, 2));

    const state = payload.state;

    switch (state.kind) {
      case 'Disconnected': {
        serialStore.device = null;

        installationStore.updateState = 'Stopped';

        break;
      }

      case 'Ready': {
        serialStore.device = state.device;

        installationStore.updateState = 'Stopped';

        break;
      }

      case 'Downloading': {
        serialStore.device = state.device;

        installationStore.downloadStatus = state.status;

        installationStore.updateLog.push({
          line: `Downloading... ${(installationStore.downloadProgress * 100).toFixed(2)}%`,
          state: 'Starting',
        });
        break;
      }

      case 'Updating': {
        serialStore.device = state.device;

        if (state.status.log) {
          const logs: LogEntry[] = [];

          const outputRegex = /(?:^\s*upload@\S+)(?:\s+)(?<log>.*$)/gm;

          let line;

          while (null != (line = outputRegex.exec(state.status.log)?.groups?.['log'])) {
            logs.push({ line, state: state.status.state });
          }

          installationStore.updateLog.push(...logs);
        }

        installationStore.updateState =
          state.status.state === 'Error' ? 'Stopped' : state.status.state;

        if (
          state.status.state === 'Starting' &&
          installationStore.downloadStatus.state === 'Complete'
        ) {
          installationStore.downloadStatus.state = 'Stopped';
        }
        break;
      }

      case 'Error': {
        serialStore.device = state.device;

        installationStore.updateState = 'Stopped';

        installationStore.updateLog.push({
          line: state.message,
          state: 'Error',
        });

        break;
      }
    }
  }

  async function startListeners() {
    if (listenersStarted) {
      return;
    }

    unlisten = await registerIpcEventListener('device-state-update', handleDeviceStateUpdate);

    listenersStarted = true;
  }

  async function selectCustomPath(path: string, version?: string | null) {
    const parsedVersion = version ?? parseFirmwareFilename(path)?.version;

    if (!parsedVersion) {
      return;
    }

    await installationStore.selectVersion({
      path,
      source: 'local',
      version: parsedVersion,
    });
  }

  if (import.meta.hot) {
    import.meta.hot.dispose(() => {
      try {
        unlisten?.();
      } catch {
        /* noop */
      }

      unlisten = null;

      listenersStarted = false;
    });
  }

  return {
    selectCustomPath,
    startListeners,
  } as const;
};
