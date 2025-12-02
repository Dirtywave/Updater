<script setup lang="ts">
import { computed, ref } from 'vue';
import VersionNumber from 'components/VersionNumber.vue';

type Props = {
  expanded?: boolean;
  hideChangelogOnlyBadge?: boolean;
  isSelected: boolean;
  isDisabled?: boolean;
  selectedValue: string | undefined;
  onMainAction?: () => void;
  onSecondaryAction?: () => void;
  primaryLabel: string;
  captionLabel: string;
  showBracketsOnHover?: boolean;
  version?: string;
  showVersionNumber?: boolean;
};

const {
  expanded = false,
  hideChangelogOnlyBadge = false,
  isDisabled = false,
  isSelected,
  onMainAction,
  showBracketsOnHover = true,
  showVersionNumber = true,
  ...props
} = defineProps<Props>();

const focusedMainActionToggle = ref(false);

const renderBrackets = computed(() => !isSelected);
</script>

<template>
  <q-item
    v-brackets="{
      disabled: isDisabled,
      render: renderBrackets,
      selected: isSelected,
    }"
    :tabindex="isDisabled ? -1 : undefined"
    :class="[
      'bg-dark-page column full-width no-quasar-focus-helper relative-position version',
      {
        'cursor-pointer': !isDisabled,
        selected: isSelected,
      },
    ]"
  >
    <q-item-section class="bg-dark-page full-width items-stretch justify-start version-header">
      <div class="col column items-stretch justify-between">
        <div class="col column items-stretch justify-between version-header-info">
          <div class="col row full-width q-px-none text-no-wrap">
            <div class="col items-center justify-between row">
              <div class="col full-height">
                <q-btn
                  v-brackets="{
                    focusOnly: true,
                    offset: 1,
                    onFocusChange: (focused: boolean) => (focusedMainActionToggle = focused),
                  }"
                  @click="onMainAction"
                  :tabindex="isDisabled ? -1 : undefined"
                  :ripple="false"
                  unelevated
                  :class="[
                    { 'no-pointer-events': isDisabled },
                    'fit items-stretch q-pa-none q-pl-sm',
                  ]"
                  style="padding-top: 1px; padding-bottom: 1px"
                >
                  <div class="full-width row space-between">
                    <div class="column full-height items-start justify-center q-pb-xs q-pt-sm">
                      <q-item-label
                        :class="[
                          'label',
                          {
                            'is-disabled': isDisabled,
                            'text-text-disabled': isDisabled,
                            'text-secondary': !isSelected && !isDisabled,
                            'text-primary': isSelected,
                          },
                        ]"
                      >
                        {{ primaryLabel }}
                        <span v-if="showVersionNumber && version">
                          <VersionNumber
                            :color="undefined"
                            :selected="isSelected"
                            :version="version"
                            :class="[
                              'version-number',
                              { 'is-disabled text-text-disabled': isDisabled },
                            ]"
                          />
                        </span>
                      </q-item-label>

                      <q-item-label caption class="text-default">
                        {{ captionLabel }}
                      </q-item-label>
                    </div>

                    <q-space />

                    <slot name="main-action-aside" />
                  </div>
                </q-btn>
              </div>

              <div v-if="isDisabled" class="q-mx-xs">
                <transition name="obscured">
                  <q-badge
                    v-if="!hideChangelogOnlyBadge"
                    color="dark-page"
                    :role="undefined"
                    text-color="text-disabled"
                    class="no-border-radius non-selectable"
                  >
                    changelog only
                  </q-badge>
                </transition>
              </div>

              <!-- <div v-if="$slots.aside" class="row self-stretch"> -->
              <slot name="aside" :expanded />
              <!-- </div> -->
            </div>
          </div>
        </div>
      </div>
    </q-item-section>

    <slot name="content" />
  </q-item>
</template>

<style lang="scss" scoped>
@use '/node_modules/quasar/dist/quasar.css';
@use 'sass:color';
@use 'src/css/colors.scss' as colors;

.obscured {
  &-enter-from,
  &-leave-to {
    opacity: 0;
    transition: 0.25s opacity ease;
  }
}

.version {
  border: none;
  // padding: 1px !important;
  padding: 0 !important;
  text-align: start;

  &:hover {
    .label:not(.is-disabled) {
      color: var(--q-primary) !important;
    }

    .q-badge {
      background-color: colors.$text-disabled !important;
      color: var(--q-dark-page) !important;
    }

    .version-number:not(.is-disabled) {
      color: var(--q-primary) !important;
    }
  }

  &-header {
    position: sticky;
    top: 0;
    z-index: 1;

    &-info {
      background: $dark-page;
    }
  }

  &.q-item {
    & .q-btn {
      text-transform: unset;

      &:hover {
        & :deep(.q-focus-helper) {
          opacity: 0;
        }
      }
    }
  }

  &.selected {
    &::after {
      border: 1px solid var(--q-accent);
      content: '';
      top: 0;
      left: 0;
      right: 0;
      bottom: 0;
      pointer-events: none;
      position: absolute;
      transition: border-color ease 0.25s;
      z-index: 1;
    }

    &:hover {
      &::after {
        border-color: var(--q-primary);
        transition: none;
      }
    }

    &:active {
      &::after {
        filter: drop-shadow(0 0 4px var(--q-primary));
      }
    }
  }
}
</style>
