/// <reference types="vite/client" />
export {};

import type { BracketsDirective } from 'directives/hover-brackets';

// declare module '*.vue' {
//   import type { DefineComponent } from 'vue';

//   const component: DefineComponent<object, object, unknown>;

//   export default component;
// }

declare module 'vue' {
  interface Directives {
    brackets: BracketsDirective;
  }

  interface GlobalDirectives {
    brackets: BracketsDirective;
  }
}
