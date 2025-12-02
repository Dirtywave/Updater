<script lang="ts" setup>
import AuxiliaryPage from 'components/AuxiliaryPage.vue';
import TroubleshootingContent from 'components/TroubleshootingContent.vue';
import VersionNumber from 'components/VersionNumber.vue';
import packageJson from '../../package.json';
import { onMounted, reactive, ref } from 'vue';
import { fetchM8OperationManualDownloadLink, resourcesAndDownloadsUrl } from 'src/utils';
import { emitTo } from '@tauri-apps/api/event';

const emit = defineEmits<{
  close: [];
}>();

const links: { callToAction: string; label: string; caption: string; href: string }[] = reactive([
  {
    callToAction: 'visit',
    caption: 'https://dirtywave.com/',
    href: 'https://dirtywave.com/',
    label: 'Website',
  },
  {
    callToAction: 'email',
    caption: 'support@dirtywave.com',
    href: 'mailto:support@dirtywave.com',
    label: 'Support',
  },
  {
    callToAction: 'join',
    caption: 'official discord server',
    href: 'https://discord.gg/dirtywave',
    label: 'Community',
  },
]);

const manualLink = ref<(typeof links)[number]>({
  callToAction: 'learn',
  caption: 'M8 operation manual',
  href: resourcesAndDownloadsUrl,
  label: 'Manual',
});

links.push(manualLink.value);

onMounted(async () => (manualLink.value.href = await fetchM8OperationManualDownloadLink()));

const showLogs = async () => await emitTo('main', 'show-logs');
</script>

<template>
  <AuxiliaryPage ref="auxiliaryPage" @close="emit('close')" title="Troubleshooting & More">
    <q-scroll-area class="fit q-pr-md">
      <q-list dense class="col-auto full-width q-pa-none q-pl-xs settings-list">
        <q-item-label header class="justify-between row items-center q-pb-none q-pr-none">
          <div class="row q-gutter-x-xs">
            <div>Version</div>

            <div><VersionNumber color="var(--q-primary)" :version="packageJson['version']" /></div>
          </div>

          <q-space />

          <div>
            <q-btn
              v-brackets
              @click="showLogs"
              :ripple="false"
              color="white"
              label="show logs"
              size="sm"
              flat
              class="no-hover no-quasar-focus-helper q-px-sm show-logs-button"
            />
          </div>
        </q-item-label>

        <q-item-label header>Links</q-item-label>

        <q-item
          v-brackets
          v-for="{ callToAction, caption, href, label } in links"
          :key="href"
          :href
          tag="button"
          target="_blank"
          clickable
          class="full-width link no-padding no-quasar-focus-helper q-ml-xs"
        >
          <q-item-section class="q-pl-sm q-py-xs">
            <q-item-label>{{ label }}</q-item-label>

            <q-item-label caption class="caption">{{ caption }}</q-item-label>
          </q-item-section>

          <q-item-section
            avatar
            class="col-3 call-to-action--container q-mr-sm text-caption text-uppercase"
          >
            {{ callToAction }}
          </q-item-section>
        </q-item>

        <q-item-label header>Troubleshooting</q-item-label>

        <q-item class="no-padding">
          <TroubleshootingContent class="q-pb-md" />
        </q-item>
      </q-list>
    </q-scroll-area>
  </AuxiliaryPage>
</template>

<style lang="scss" scoped>
.call-to-action {
  &:hover {
    color: var(--q-primary);
  }
}

.caption {
  color: unset;
}

.close-button-container {
  padding-right: 0.1em;
}

.link {
  background: transparent;
  border: none;
  text-align: start;

  // QItem has a default tween applied, need to clear that
  transition-duration: 0s;

  &:hover,
  &:focus {
    color: var(--q-primary);
  }
}

// .settings-list {
//   padding-right: 12px;
// }

.no-padding {
  padding: 0;
}

.show-logs-button {
  &:hover,
  &:focus {
    color: var(--q-primary) !important;
  }
}
</style>
