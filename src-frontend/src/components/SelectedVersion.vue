<script lang="ts" setup>
import { computed } from 'vue';
import VersionNumber from 'components/VersionNumber.vue';

const props = defineProps<{ selectedVersion: string | null }>();

const version = computed(() => props.selectedVersion ?? '---');
</script>

<template>
  <span class="items-center justify-between row selected-version" style="display: inline-flex">
    <Transition enter-active-class="appear animated headShake" leave-active-class="hidden">
      <div :key="selectedVersion ?? ''">
        <VersionNumber :version="version" color="var(--q-primary)" />
      </div>
    </Transition>
  </span>
</template>

<style lang="scss" scoped>
.selected-version {
  cursor: default;
}
</style>
