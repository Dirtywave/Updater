<script setup lang="ts">
import { useDragDropListener } from 'src/composables/use-drag-drop-listener';

const { maybePaths } = useDragDropListener();
</script>

<template>
  <Transition enter-active-class="animated appear fadeIn" leave-active-class="animated fadeOut">
    <Teleport v-if="maybePaths.length > 0" to="#overlay">
      <section class="bg-aero column fit items-center justify-center z-max">
        <div v-brackets tabindex="0" class="col column file-drop-zone fit q-pa-md">
          <div class="col column file-drop-zone-content q-py-md rounded-borders">
            <div class="col column items-center justify-center">
              <div class="relative-position">
                <q-icon color="accent" name="add_circle_outline" size="5rem" class="glow-accent" />
              </div>
            </div>
          </div>
        </div>
      </section>
    </Teleport>
  </Transition>
</template>

<style lang="scss" scoped>
.file-drop-zone {
  &-content {
    border: 1px dashed var(--q-accent);
  }
}
</style>
