export type DownloadState = 'Stopped' | 'Starting' | 'Downloading' | 'Complete' | 'Error';

export type UpdateState =
  | 'Stopped'
  | 'Initializing'
  | 'Starting'
  | 'Updating'
  | 'Finalizing'
  | 'Error';

// add   	This board was plugged in or was already there
// change 	Something changed, maybe the board rebooted
// miss 	This board is missing, either it was unplugged (remove) or it is changing mode
// remove 	This board has been missing for some time, consider it removed

export type Capability = 'reboot' | 'reset' | 'rtc' | 'run' | 'serial' | 'unique' | 'update';

export type DeviceAction = 'add' | 'change' | 'miss' | 'remove';

export type DeviceType = 'HEADLESS' | 'MODEL01' | 'MODEL02' | 'UNKNOWN';

export type TyCmdListEntry = {
  action: DeviceAction;
  capabilities: Capability[];
  description: string;
  interfaces: string[][];
  location: string;
  model: string;
  serial: string;
  tag: string;
};

export type Device = {
  action_history: DeviceAction[];
  device_type: DeviceType;
  ty_cmd_info: TyCmdListEntry;
  updated_at: number;
};

export type OptionalLog = {
  log: string | null;
};

export type DownloadStatus = OptionalLog & {
  bytes_downloaded: number;
  size: number;
  state: DownloadState;
};

export type UpdateStatus = OptionalLog & {
  state: UpdateState;
};

export type IpcEvent = 'device-state-update';

type PayloadWrapper<
  R extends {
    [k in IpcEvent]: unknown;
  },
> = R;

export type DeviceState =
  | { kind: 'Disconnected' }
  | { kind: 'Ready'; device: Device }
  | { kind: 'Downloading'; device: Device; status: DownloadStatus }
  | { kind: 'Updating'; device: Device; status: UpdateStatus }
  | { kind: 'Error'; device: Device; message: string };

export type DeviceStateUpdate = {
  state: DeviceState;
};

export type IpcEventPayloads = PayloadWrapper<{
  'device-state-update': DeviceStateUpdate;
}>;
