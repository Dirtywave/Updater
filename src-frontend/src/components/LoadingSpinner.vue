<script setup lang="ts">
import { onMounted, onUnmounted, ref } from 'vue';

defineProps<{ size?: string }>();

const numRows = 2;
const numCols = 2;
const perimeter = numRows * 2 + numCols * 2 - 4;
const pos = ref(0); // __draw_position
const speedPerimeterPerSecond = 6;

let rafId = 0;
let last = 0;

function distanceAlongPerimeter(a: number, b: number) {
  const forward = (a - b + perimeter) % perimeter;
  const backward = (b - a + perimeter) % perimeter;
  return Math.min(forward, backward);
}

function brightnessFor(selected: number, current: number) {
  const d = distanceAlongPerimeter(current, selected);

  return Math.max(0, Math.min(1, 1 - d / 2));
}

onMounted(() => {
  const step = (t: number) => {
    if (!last) {
      last = t;
    }

    const dt = (t - last) / 1000;

    last = t;

    // Advance position time‑based to avoid frame‑rate dependence
    pos.value = (pos.value + speedPerimeterPerSecond * dt) % perimeter;

    rafId = requestAnimationFrame(step);
  };
  rafId = requestAnimationFrame(step);
});

onUnmounted(() => {
  cancelAnimationFrame(rafId);
});

const indices = [
  0, // (0,0) top-left
  1, // (0,1) top-right
  3, // (1,0) bottom-left (note: bottom row counts backward)
  2, // (1,1) bottom-right
];
</script>

<template>
  <div :class="[{ fit: !size, size }, 'spinner-container']">
    <div
      v-for="i in 4"
      :key="i"
      class="spinner-segment"
      :style="{
        // Compute brightness per frame, single clock
        opacity: brightnessFor(indices[i - 1]!, pos).toFixed(3),
        // Optional: subtle hue shift to simulate color mixing (can remove)
        filter: `saturate(${(0.6 + 0.4 * brightnessFor(indices[i - 1]!, pos)).toFixed(2)})`,
      }"
    />
  </div>
</template>

<style lang="scss" scoped>
.size {
  height: v-bind('size');
  width: v-bind('size');
}

.spinner {
  &-container {
    display: grid;
    gap: 1px;
    grid: 1fr 1fr / 1fr 1fr;
  }

  &-segment {
    background-color: var(--q-accent);
  }
}
</style>

<!-- <script setup lang="ts">
defineProps<{ size?: string }>();
</script>

<template>
  <div :class="[{ fit: !size, size }, 'spinner-container']">
    <div class="spinner-segment" style="--index: 0" />

    <div class="spinner-segment" style="--index: 1" />

    <div class="spinner-segment" style="--index: 3" />

    <div class="spinner-segment" style="--index: 2" />
  </div>
</template>

<style lang="scss" scoped>
@keyframes pulse {
  0% {
    opacity: 1;
  }

  50% {
    opacity: 0;
  }
}

.size {
  height: v-bind('size');
  width: v-bind('size');
}

.spinner {
  &-container {
    display: grid;
    gap: 1px;
    grid: 1fr 1fr / 1fr 1fr;
  }

  &-segment {
    --animation-delay: 200;

    animation: pulse 0.8s infinite;
    animation-delay: calc(var(--index) * var(--animation-delay) * 1ms);
    background-color: var(--q-accent);
  }
}
</style> -->
