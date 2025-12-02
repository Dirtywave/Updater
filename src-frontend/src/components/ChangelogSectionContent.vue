<script lang="ts" setup>
import { type ChangelogSection } from 'src/types';
import { changelogEntryTypeColors } from 'src/types';
import ChangelogLine from 'components/ChangelogLine.vue';

defineProps<{ section: ChangelogSection }>();
</script>

<template>
  <ul class="changelog-section-content">
    <li v-for="entry in section.entries" :key="entry.description" class="entry q-my-xs">
      <div class="column">
        <div class="changelog-entry">
          <q-badge
            :color="changelogEntryTypeColors[entry.type]"
            :label="entry.type"
            :role="undefined"
            text-color="dark"
            :class="`changelog-entry-type-badge changelog-entry-type-badge--${entry.type} q-mr-xs no-border-radius`"
          />

          <ChangelogLine :line="entry.description" />
        </div>

        <ul v-if="(entry.details?.length ?? 0) > 0">
          <li
            v-for="detail in entry.details"
            :key="detail"
            :class="`changelog-entry indented-entry-${entry.type} q-ml-lg q-pl-sm`"
          >
            <ChangelogLine :line="detail" />
          </li>
        </ul>
      </div>
    </li>
  </ul>
</template>

<style lang="scss" scoped>
.changelog-entry {
  &:hover {
    & span {
      border-bottom: 1px dashed white;
    }
  }

  &-type-badge {
    // Visually centers horizontally with the text, for some reason
    transform: translateY(-1px);
    padding: 0.125em 0.25em;
    //   &--change {
    //     letter-spacing: -0.0625em;
    //   }

    //   &--fix {
    //     letter-spacing: -0.125em;
    //   }

    //   &--improved {
    //     letter-spacing: -0.0625em;
    //   }

    //   &--new {
    //     letter-spacing: -0.0625em;
    //   }
  }
}

.changelog-section-content {
  cursor: text;

  // Changelog entries containing URLs (e.g. https://github.com/DirtyWave/M8DisplayTouchdesigner)
  // cause the section to overflow, introducing horizontal scrollbars
  // and pushing content out of the window bounds.
  overflow-wrap: anywhere;

  body.screen--xs & {
    font-size: 0.7rem;
  }
}

.indented-entry {
  &-change {
    border-left: 1px solid $purple-12;
  }

  &-fix {
    border-left: 1px solid $amber-14;
  }

  &-improved {
    border-left: 1px solid $teal-13;
  }

  &-new {
    border-left: 1px solid $light-green-13;
  }
}
</style>
