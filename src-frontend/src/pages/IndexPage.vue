<script setup lang="ts">
import { watch } from 'vue';
import VersionList from 'src/components/VersionList.vue';
import { QScrollArea } from 'quasar';
import { useDragDropListener } from 'src/composables/use-drag-drop-listener';
import { useDeviceStateController } from 'src/composables/controllers/use-device-state-controller';
import { parseFirmwareFilename } from 'src/utils/filename-parsing';
import LocalFileSelectItem from 'components/LocalFileSelectItem.vue';

const { paths } = useDragDropListener();
const { selectCustomPath } = useDeviceStateController();

watch(paths, async () => {
  if (paths.value[0]?.path) {
    const filename = paths.value[0]?.name;

    const parsed = parseFirmwareFilename(filename);

    await selectCustomPath(paths.value[0]?.path, parsed?.version ?? null);
  }
});
</script>

<template>
  <q-page class="relative-position">
    <Suspense>
      <Transition appear enter-active-class="animated fadeIn" leave-active-class="animated fadeOut">
        <div class="absolute-full">
          <div class="fit column items-stretch no-wrap">
            <div class="col q-pl-sm q-pr-sm q-pt-sm">
              <q-scroll-area class="relative-position fit q-pr-md version-list-scroll-area">
                <VersionList />

                <!-- Ensures that the last entry can be viewed without the shadow fade covering it -->
                <div class="version-list-end-spacer" />
              </q-scroll-area>
            </div>

            <div class="col-auto local-file-select-container">
              <LocalFileSelectItem />
            </div>
          </div>
        </div>
      </Transition>

      <template #fallback>
        <Transition
          appear
          enter-active-class="animated fadeIn"
          leave-active-class="animated fadeOut"
        >
          <section class="full-height row justify-center items-center">
            <q-img
              style="max-height: 16rem"
              :loading-show-delay="500"
              class="pulse"
              fit="scale-down"
              src="~assets/icon-transparent-background.svg"
            />
          </section>
        </Transition>
      </template>

      <template #error>
        <div class="text-negative">
          Failed to load firmware list. You can still select a local file.
        </div>
      </template>
    </Suspense>
  </q-page>
</template>

<style>
@keyframes pulse {
  0%,
  100% {
    opacity: 1;
  }

  50% {
    opacity: 0.5;
  }
}
</style>

<style lang="scss" scoped>
:deep(.firmware-tab) {
  --size: 2rem;

  height: var(--size);
  max-height: var(--size);
  min-height: var(--size);

  &.left {
    border-top-left-radius: 1rem;
  }

  &.right {
    border-top-right-radius: 1rem;
  }

  &.glow {
    .q-tab__content {
      filter: drop-shadow(0 0 4px currentcolor);
    }

    .q-tab__indicator {
      filter: drop-shadow(0 0 4px currentcolor);
    }
  }

  .q-tab__icon {
    --size: 1em;

    width: var(--size);
    height: var(--size);
    font-size: var(--size);
  }

  .q-tab__indicator {
    height: 1px;
  }

  .q-tab__label {
    font-size: 0.75em;
  }
}

.drag-and-drop-button {
  background: var(--q-dark-page);
  border-left: unset;
  border-top: unset;
  border-right: unset;
  // border-bottom: 1px solid $grey-9;
  border-bottom: unset;
  line-height: unset;
  text-decoration: unset;
  transition: 0.2s ease filter;
  color: $grey-5;

  &--container {
    // border-bottom: 1px solid var(--q-dark-page);
    position: relative;
    // box-shadow:
    //   inset 0px 3px 5px -3px rgba(0, 0, 0, 0.1),
    //   inset 0px 6px 10px -1px rgba(0, 0, 0, 0.07),
    //   inset 0px 1px 14px -2px rgba(0, 0, 0, 0.06),
    //   inset 0px -3px 5px -3px rgba(0, 0, 0, 0.1),
    //   inset 0px -6px 10px -1px rgba(0, 0, 0, 0.07),
    //   inset 0px -1px 14px -2px rgba(0, 0, 0, 0.06);

    &:after {
      background: linear-gradient(
        0deg,
        #111111 0%,
        rgba(20, 20, 20, 0.9) 5%,
        transparent 30%,
        transparent 70%,
        rgba(20, 20, 20, 0.9) 95%,
        #111111 100%
      );
      bottom: 0;
      content: '';
      left: 0;
      pointer-events: none;
      position: absolute;
      right: 0;
      top: 0;
    }
  }
}

.local-file-select-container {
  border-bottom: 1px solid transparent;
}

.flash-firmware-button {
  border-color: var(--q-primary);
  border-width: 1px;

  &:not(.disabled) {
    border-style: solid;
  }

  border-bottom-left-radius: 7px;
  transform: translateY(0.33em);
}

.progress-container {
  :deep(.q-linear-progress__track) {
    opacity: 1;
  }
}

.pulse {
  animation: pulse 2s ease infinite;
}

.selected-version-container {
  min-width: 28ch;
}

.version-list {
  &-end-spacer {
    height: 8em;
  }

  &-scroll-area {
    min-height: 1px;

    &::after {
      background: linear-gradient(
        180deg,
        rgba($dark-page, 0) 0%,
        rgba($dark-page, 0.33) 33.33%,
        rgba($dark-page, 0.66) 66.66%,
        $dark-page 100%
      );

      bottom: 0;
      content: '';
      left: 0;
      pointer-events: none;
      position: absolute;
      right: 0;
      top: 75%;
      z-index: 4000;
    }
  }
}

.bg-color-cycle {
  animation: bg-color-cycle 1.5s linear infinite;
}

:deep(.q-tab) {
  min-height: unset;

  .q-focus-helper {
    color: transparent;

    &::after {
      background: transparent;
    }
  }

  .q-tab__indicator {
    @extend .bg-color-cycle;
    height: 1px;
    width: 60%;
    left: 20%;

    // &::before {
    //   content: '';
    //   background: white;
    //   height: 4px;
    //   left: 0;
    //   right: 0;
    //   position: absolute;
    //   // filter: blur(20px);
    //   z-index: -1;
    // }
  }
}
</style>
