import { storeToRefs } from 'pinia';

import type { FirmwareSource } from 'src/stores/installation';
import { useInstallationStore } from 'src/stores/installation';
import { useFirmwareStore } from 'src/stores/firmware';
import { useFirmwareList } from 'src/composables/use-firmware-list';
// import { parseFirmwareFilename } from "src/utils/filename-parsing";

export function useFirmwareController() {
  const installation = useInstallationStore();

  const { cachedLocalFirmware, selectedFirmware } = storeToRefs(installation);

  const firmwareStore = useFirmwareStore();

  const { firmwares, entries } = storeToRefs(firmwareStore);

  const { fetchFirmwareList } = useFirmwareList();

  const isSelected = (version: string | null, path?: string) =>
    selectedFirmware.value?.version === version &&
    (path ? selectedFirmware.value?.path === path : true);

  const selectVersion = async (
    versionOrObj: string | { path: string; source: FirmwareSource; version: string },
  ) => {
    if (typeof versionOrObj === 'string') {
      const firmware = firmwares.value.find((f) => f.version === versionOrObj);

      if (firmware) {
        await installation.selectVersion({
          ...firmware,
          path: firmware.path,
          source: 'remote',
          version: firmware.version,
        });
      }
    } else {
      await installation.selectVersion(versionOrObj);
    }
  };

  return {
    cachedLocalFirmware,
    entries,
    fetchFirmwareList,
    firmwares,
    isSelected,
    selectedFirmware,
    selectVersion,
  } as const;
}
