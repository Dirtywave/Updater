import HoverBrackets from 'boot/hover-brackets';
import Tauri from 'boot/tauri';
import { defineBoot, type BootCallback } from 'boot/types';

const bootFunctions: BootCallback[] = [HoverBrackets, Tauri];

export default defineBoot(async (params) => {
  await Promise.all(
    bootFunctions
      .map((callback) => callback(params))
      .map((result) => (typeof result === 'object' ? result : Promise.resolve())),
  );
});
