<script setup lang="ts">
import { tokenizeChangelogLine } from 'src/utils';
import { computed } from 'vue';
import LineToken from 'components/LineToken.vue';

const props = defineProps<{
  line: string;
}>();

const tokens = computed(() => tokenizeChangelogLine(props.line));
</script>

<template>
  <span class="changelog-entry-description">
    <LineToken
      v-for="token in tokens"
      :key="`${token.start}${token.end}${token.type}${token.value}`"
      :token="token"
    />
  </span>
</template>

<style lang="scss" scoped>
.changelog-entry-description {
  font-family: monospace;
}

.token {
  &-caps {
    color: green;
  }

  &-number {
    color: red;
  }

  &-plain {
    color: cyan;
  }
}
</style>
