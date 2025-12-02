<template>
  <div class="relative-position">
    <!-- <div class="absolute-full items-center justify-center row settings-button-update-hint">
      <q-icon color="primary" name="settings_suggest" size="1.25em" class="glow-primary q-px-xs" />
    </div> -->

    <q-btn
      v-bind="$attrs"
      text-color="dirty-white"
      color="dirty-white"
      icon="settings"
      ref="closeButton"
      size="0.59em"
      dense
      flat
      round
      class="q-px-xs settings-button"
    >
      <q-tooltip>Settings</q-tooltip>
    </q-btn>
  </div>
</template>

<style lang="scss" scoped>
@use '/node_modules/quasar/dist/quasar.css';
@use 'src/css/colors.scss' as colors;

.settings-button {
  // animation: pingPongColor 4.5s ease-in infinite;

  @keyframes pingPongColor {
    0% {
      filter: drop-shadow(0 0 2px colors.$dirty-white);
      color: colors.$dirty-white;
    }

    50% {
      filter: none;
      color: var(--q-primary);
    }

    100% {
      filter: drop-shadow(0 0 2px colors.$dirty-white);
      color: colors.$dirty-white;
    }
  }
}

.settings-button-update-hint {
  // animation: pingPongOpacity 4.5s ease-in infinite;
  left: 3.5px;
  top: -2.5px;

  @keyframes pingPongOpacity {
    0% {
      opacity: 0;
    }

    50% {
      opacity: 1;
    }

    100% {
      opacity: 0;
    }
  }
}
</style>
