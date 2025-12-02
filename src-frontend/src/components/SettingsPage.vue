<script lang="ts" setup>
import AuxiliaryPage from 'components/AuxiliaryPage.vue';
import ColorText from 'components/ColorText.vue';
import VersionNumber from 'components/VersionNumber.vue';
import { getCssVar, QCheckbox } from 'quasar';
import { useDistanceToElements } from 'src/composables';
import { colorTween } from 'src/utils';
import { computed, ref, useTemplateRef } from 'vue';
import packageJson from '../../package.json';

const emit = defineEmits<{
  close: [];
}>();

const automaticUpdatesEnabled = ref(true);

function toggleRadioCheckbox() {
  automaticUpdatesEnabled.value = !automaticUpdatesEnabled.value;
}

const automaticUpdatesEnabledCheckboxRef = useTemplateRef<QCheckbox>(
  'automaticUpdatesEnabledCheckbox',
);

const automaticUpdatesEnabledCheckbox = computed(() => {
  if (automaticUpdatesEnabledCheckboxRef.value?.$el) {
    return automaticUpdatesEnabledCheckboxRef.value.$el as HTMLElement;
  }

  return null;
});

const primary = getCssVar('primary') ?? '';
const secondary = getCssVar('secondary') ?? '';

const { distances } = useDistanceToElements(automaticUpdatesEnabledCheckbox, { threshold: 200 });

const colors = computed(() =>
  distances.value?.map((percentage) =>
    colorTween({
      percentage,
      from: primary,
      to: secondary,
    }),
  ),
);

const automaticUpdatesEnabledCheckboxStyle = computed(() => ({
  '--color': colors.value[0],
  '--shadow-color': colors.value[0],
  color: 'var(--color)',
  overflow: 'visible',
  filter: `drop-shadow(0 0 ${(distances.value?.[0] ?? 0) * 7}px var(--shadow-color)`,
}));
</script>

<template>
  <AuxiliaryPage @close="emit('close')" title="Settings">
    <section class="column fit items-center justify-center non-selectable q-pl-sm q-pt-sm">
      <q-list dense class="col-auto full-width settings-list" style="max-width: 33ch">
        <q-item :clickable="false">
          <q-item-section>
            <q-item-label>Version</q-item-label>
          </q-item-section>

          <q-item-section avatar>
            <VersionNumber :version="packageJson['version']" />
          </q-item-section>
        </q-item>

        <q-space />

        <q-item-label header>Updates</q-item-label>

        <q-item v-ripple="false" tag="label">
          <q-item-section>
            <q-item-label>Check on Startup</q-item-label>

            <!-- <q-item-label caption>Enable checking for updates at start</q-item-label> -->
          </q-item-section>

          <q-item-section avatar>
            <q-radio
              :model-value="automaticUpdatesEnabled"
              :val="true"
              @click="toggleRadioCheckbox"
              :color="automaticUpdatesEnabled ? 'accent' : undefined"
              checked-icon="task_alt"
              keep-color
              class="checkbox"
              :style="automaticUpdatesEnabledCheckboxStyle"
              ref="automaticUpdatesEnabledCheckbox"
            />
            <!-- <q-checkbox ref="automaticUpdatesEnabledCheckbox" v-model="automaticUpdatesEnabled"
              :color="automaticUpdatesEnabled ? 'accent' : undefined" :keep-color="true" checked-icon="task_alt"
              size="lg" unchecked-icon="panorama_fish_eye" dense class="checkbox"
              :style="automaticUpdatesEnabledCheckboxStyle" /> -->
          </q-item-section>
        </q-item>

        <q-item v-ripple="false" tag="label" class="q-mt-xs">
          <q-item-section>
            <q-item-label>Apply on Startup</q-item-label>

            <!-- <q-item-label caption> updates at start</q-item-label> -->
          </q-item-section>

          <q-item-section avatar>
            <q-checkbox
              ref="automaticUpdatesEnabledCheckbox"
              v-model="automaticUpdatesEnabled"
              :color="automaticUpdatesEnabled ? 'accent' : undefined"
              :keep-color="true"
              checked-icon="task_alt"
              unchecked-icon="panorama_fish_eye"
              class="checkbox"
              :style="automaticUpdatesEnabledCheckboxStyle"
            />
          </q-item-section>
        </q-item>

        <q-item v-ripple="false" class="q-mt-xs">
          <q-item-section>
            <q-btn
              color="accent"
              label="Check for Updates"
              size="sm"
              dense
              text-color="dark"
              class="text-bold"
            />
          </q-item-section>
        </q-item>

        <q-space />

        <q-item-label header>Links</q-item-label>

        <q-item :clickable="false" class="q-gutter-x-sm">
          <q-item-section>
            <q-item-label>Website</q-item-label>

            <q-item-label caption>https://dirtywave.com/</q-item-label>
          </q-item-section>

          <q-item-section avatar class="col-3 call-to-action--container">
            <ColorText :from="primary" :to="secondary" as-div class="full-width">
              <q-btn
                href="https://dirtywave.com/"
                label="Visit"
                size="sm"
                target="_blank"
                dense
                outline
                class="call-to-action full-width glow-current-color q-px-md"
              />
            </ColorText>
          </q-item-section>
        </q-item>

        <q-item :clickable="false" class="q-gutter-x-sm q-mt-sm">
          <q-item-section>
            <q-item-label>Support</q-item-label>

            <q-item-label caption>support@dirtywave.com</q-item-label>
          </q-item-section>
          <q-item-section avatar class="col-3 call-to-action--container">
            <ColorText :from="primary" :to="secondary" as-div class="full-width">
              <q-btn
                href="mailto:support@dirtywave.com"
                label="Email"
                size="sm"
                target="_blank"
                dense
                outline
                class="call-to-action full-width glow-current-color q-px-md"
              />
            </ColorText>
          </q-item-section>
        </q-item>

        <q-item :clickable="false" class="q-gutter-x-sm q-mt-sm">
          <q-item-section class="">
            <q-item-label>Community</q-item-label>

            <q-item-label caption>official Discord server</q-item-label>
          </q-item-section>

          <q-item-section avatar class="col-3 call-to-action--container">
            <ColorText :from="primary" :to="secondary" as-div class="full-width">
              <q-btn
                href="https://discord.gg/dirtywave"
                label="Join"
                size="sm"
                target="_blank"
                dense
                outline
                class="call-to-action full-width glow-current-color"
              />
            </ColorText>
          </q-item-section>
        </q-item>
      </q-list>
    </section>
  </AuxiliaryPage>
</template>

<style lang="scss" scoped>
@use 'sass:map';

.call-to-action {
  &--container {
    padding-left: 0;
  }

  &:hover {
    color: var(--q-accent);
  }
}

.close-button-container {
  padding-right: 0.1em;
}

:deep(.q-item) {
  .q-focus-helper {
    background: transparent;

    &::after {
      opacity: 0;
    }
  }
}

.checkbox {
  &:hover {
    --shadow-color: var(--q-accent) !important;
    color: var(--q-accent) !important;
    font-size: 4rem;

    & :deep(.q-checkbox__inner) {
      color: var(--q-accent);
    }
  }

  & :deep(.q-checkbox__inner) {
    color: var(--color);
  }
}

.settings-list {
  :deep(.q-item) {
    padding: 0 map.get($space-sm, 'x');
  }
}
</style>
