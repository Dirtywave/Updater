import type { Device } from 'src/types';
// When HalfKay (flash failure) - ["unique", "update", "reset", "rtc"]

// Plugged in and ready to Flash
// add - [unique run rtc reboot serial]

// Flashing started (reboot)
// add|miss - [unique]

// Flashing
// add|miss|change - [unique update reset rtc]

// Reboot
// add|miss|change|miss - [unique]

// Done
// add|miss|change - [unique run rtc reboot serial]

// --- Attempt to determine state via unique (not the literal "unique" one) capabilities

// Remove "rtc" and "unique" from all capabilities arrays. If the array is empty we are rebooting/shutting down

// "update" is only present when
// 1. Flashing is happening
// 2. Flash fails (description is "HalkKay")

// [run reboot serial] when device is not flashing/not in error state
// Should be able to just key off of any of these

// When HalfKay (flash failure) - [, "update", "reset"]

// Plugged in and ready to Flash
// add - [ run reboot serial]

// Flashing started (reboot)
// add|miss - []

// Flashing
// add|miss|change - [ update reset]

// Reboot
// add|miss|change|miss - []

// Done
// add|miss|change - [ run reboot serial]

const hasFlashingCapability = (device: Device) => {
  if (device.ty_cmd_info.capabilities.includes('serial')) {
    return 'Ready';
  }

  // capabilities will be empty during shutdown/reboot
  if (device.ty_cmd_info.description === 'HalfKay' && device.ty_cmd_info.capabilities.length > 0) {
    return 'Ready';
  }
};

type DeviceStatus = 'Flashing' | 'Missing' | 'Ready' | 'Shutdown' | 'Unknown';

export const deviceIsMissing = (device: Device) =>
  device.ty_cmd_info.capabilities.length === 0 && Date.now() - device.updated_at > 2000;

// export const deviceIsMissing = (device: ConnectedDevice) =>
//   device.action_history.at(-1) === 'miss' && Date.now() - device.updated_at > 2000;

export const deviceStatus = (device?: Device | null): DeviceStatus => {
  switch (device?.action_history?.at(-1)) {
    case 'add': {
      if (hasFlashingCapability(device)) {
        return 'Ready';
      }

      return 'Unknown';
    }

    case 'change': {
      if (hasFlashingCapability(device)) {
        return 'Ready';
      }

      return 'Flashing';
    }

    case 'miss': {
      if (deviceIsMissing(device)) {
        return 'Missing';
      }

      return 'Shutdown';

      // const delta = Date.now() - device.updated_at;

      // if (delta <= 2000) {
      // 	return 'Shutdown';
      // }

      // return 'Missing';
    }
  }

  return 'Unknown';
};
