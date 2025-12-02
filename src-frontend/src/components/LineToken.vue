<script setup lang="ts">
import { getCssVar } from 'quasar';
// import {
//   //  useCategoryColor,
//   useDistanceToElements
// } from 'src/composables';
import { type Token } from 'src/utils';
// import { colorTween } from 'src/utils';
import {
  computed,
  //  useTemplateRef
} from 'vue';

const props = defineProps<{
  token: Token;
}>();

// const tokenSpan = useTemplateRef<HTMLSpanElement>('token');

// const { distances } = useDistanceToElements(tokenSpan, { threshold: 400 });

const badgeColor = computed(() => {
  if (props.token.type !== 'category') {
    return undefined;
  }

  return 'accent'; // TODO: Fully remove silly colors?... useCategoryColor()(props.token.value)
});

const color = computed(() => {
  switch (props.token.type) {
    case 'category':
    case 'plain':
      return 'unset';
    case 'keyword': {
      return getCssVar('primary');
      // TODO: Fully remove silly colors?...
      // return colorTween({
      //   percentage: distances.value?.[0] ?? 0,
      //   from: getCssVar('primary') ?? '#000',
      //   to: getCssVar('accent') ?? '#FFF',
      // })
    }
    default:
      return 'initial';
  }
});
</script>

<template>
  <span
    ref="token"
    :class="[
      `token token-type-${token.type}`,
      {
        'text-weight-bold': token.type === 'keyword',
        'mono-space-font': token.type !== 'plain',
        [`text-uppercase text-${badgeColor}`]: token.type === 'category',
      },
    ]"
  >
    {{ token.value }}
  </span>
</template>

<style lang="scss" scoped>
.token {
  color: v-bind('color');

  &-type {
    &-category {
      font-weight: bold;
      transform: translateY(-1px);
      z-index: 0;

      &::after {
        content: ' →';
        margin-left: -0.5em;
        margin-right: -0.25em;
      }
    }

    &-plain {
      color: unset;
    }
  }
}
</style>
