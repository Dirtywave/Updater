<script lang="ts" setup>
import { QExpansionItem } from 'quasar';
import { bracketsDirective } from 'directives/hover-brackets';
import { onMounted, ref, useTemplateRef } from 'vue';

type HelpSection = { content: string; header: string };

type HelpCategory = {
  defaultOpened?: boolean;
  heading: string;
  sections: HelpSection[];
};

const categories: HelpCategory[] = [
  {
    defaultOpened: false,
    heading: 'M8 is unresponsive after firmware update attempt',
    sections: [
      {
        content: 'Hold the power button for 10 seconds to ensure the M8 is powered off.',
        header: '',
      },
      {
        content:
          'Use a known good data USB cable (such as the one that came with your M8) and connect the M8 to your computer. If at all possible, avoid connecting to a USB Hub.',
        header: '',
      },
      {
        content: 'Open Dirtywave Updater',
        header: '',
      },
      {
        content:
          "Turn on the M8 by holding the power button for 2 seconds.  Depending on your M8's state, it will likely not make any sound, and the screen may also remain blank with or without the backlight illuminated.",
        header: '',
      },
      {
        content:
          'Using a small tool such as a SIM ejector key or paperclip, press and release the internal reset button inside the hole on the backside of the M8 once.',
        header: '',
      },
      {
        content:
          'Wait about 10 seconds and the Update button in Dirtywave Updater should be enabled',
        header: '',
      },
      {
        content:
          'Select firmware and click Update. It may take 10-20 seconds to update, and once it has completed, your M8 will reboot. You should now see the new firmware version appear at the bottom left corner of the Song screen for a few seconds',
        header: '',
      },
    ],
  },
  {
    defaultOpened: false,
    heading: 'M8 is not being detected',
    sections: [
      {
        content:
          'Many cables, especially cheap or free ones, lack data lines and are power-only. Try another cable; if possible, use the cable the M8 came with - it is a black, braided cable with the Dirtywave logo molded into the ends.',
        header: 'Check the USB cable',
      },
    ],
  },
];

const expansionItems = useTemplateRef<QExpansionItem[]>('expansionItems');

// Have to do a weird thing here where the directive is programmatically applied since
// there is no direct access to the focusable element (the .q-item) within the expansion item.
onMounted(() =>
  expansionItems.value
    ?.map((item) => (item.$el as HTMLElement | null | undefined)?.querySelector('.q-item'))
    .forEach((el, i) => {
      if (el) {
        bracketsDirective.mounted(el as HTMLElement, {
          instance: null,
          value: {
            // focusOnly: true, // TODO: Get the hover-only state working on parent
            onFocusChange: (focused: boolean) => {
              (expansionItems.value?.[i]?.$el as HTMLElement)?.classList.toggle('focused', focused);
            },
          },
          modifiers: {},
          oldValue: null,
          dir: bracketsDirective,
        });
      }
    }),
);

const categoriesHidingStates = ref(
  Array.from({ length: categories.length }, (_, i) => categories[i]?.defaultOpened ?? false),
);
</script>

<template>
  <section id="help-section" class="full-width">
    <q-expansion-item
      :aria-label="heading"
      ref="expansionItems"
      v-for="({ defaultOpened, heading, sections }, i) in categories"
      @after-hide="() => (categoriesHidingStates[i] = false)"
      @before-hide="() => (categoriesHidingStates[i] = true)"
      :default-opened="defaultOpened ?? false"
      :duration="150"
      :key="heading"
      group="help"
      :header-class="[{ 'bg-aero': categoriesHidingStates[i] }, 'header no-quasar-focus-helper']"
      dense
      expand-separator
      hide-expand-icon
    >
      <template #header="{ expanded }">
        <h3
          :class="[
            'heading non-selectable q-my-xs q-pl-xs q-pr-none text-subtitle2',
            { 'text-accent': expanded },
          ]"
        >
          {{ heading }}
        </h3>
      </template>

      <ol class="q-my-none q-pl-sm">
        <li v-for="{ content, header } in sections" :key="header" class="suggestion">
          <div>
            <dt class="text-bold">{{ header }}</dt>

            <dd>{{ content }}</dd>
          </div>
        </li>
      </ol>
    </q-expansion-item>
  </section>
</template>

<style lang="scss" scoped>
@use 'sass:map';

dd {
  margin-inline-start: 0;
}

#help-section {
  & :deep(.q-item) {
    transition-property: background-color;

    &:focus-visible {
      // background: red !important;
      color: var(--q-primary);
    }
  }

  & :deep(.q-item) {
    padding-left: 0.25em;
    padding-right: 0;
  }

  & :deep(li) {
    margin: map.get($space-md, 'y') 0px;
  }
}

.bg-aero {
  @extend .bg-blur;
  @extend .bg-translucent-grey;
}

.bg-blur {
  backdrop-filter: blur(5px);
  -webkit-backdrop-filter: blur(5px);
}

.bg-translucent-grey {
  background-color: rgba(32, 32, 32, 0.4);
}

.heading:hover {
  color: var(--q-primary) !important;
}

:deep(.header) {
  position: sticky;
  top: 0;
  z-index: 1;

  &.q-item {
    border-bottom: 0.5px solid rgba(255, 255, 255, 0.2);
  }
}

.q-expansion-item {
  &.q-expansion-item--expanded {
    :deep(.q-item) {
      @extend .bg-aero;
    }
  }

  :deep(.q-item) {
    &:hover {
      color: var(--q-primary);
    }
  }
}

.suggestion {
  list-style-position: inside;
}
</style>
