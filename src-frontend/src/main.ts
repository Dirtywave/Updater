import { createApp } from 'vue';

import { Notify, Quasar, Screen } from 'quasar';

import '@quasar/extras/animate/fadeIn.css';
import '@quasar/extras/animate/fadeOut.css';
import '@quasar/extras/animate/headShake.css';
import '@quasar/extras/animate/slideInUp.css';
import '@quasar/extras/animate/slideOutDown.css';

import 'quasar/src/css/index.sass';
import 'src/css/app.scss';

import App from 'src/App.vue';
import BootInit from 'boot/index';
import router from 'src/router';
import initStore from 'stores/index';

const store = initStore();

const app = createApp(App)
  .use(router)
  .use(store)
  .use(Quasar, {
    // iconSet,
    plugins: {
      Notify,
      Screen,
    }, // import Quasar plugins and add here
    config: {
      dark: true,
      screen: {
        bodyClasses: true,
      },
      // brand: {
      // primary: '#e46262',
      // ... or all other brand colors
      // },
      // notify: {...}, // default set of options for Notify Quasar plugin
      // loading: {...}, // default set of options for Loading Quasar plugin
      // loadingBar: { ... }, // settings for LoadingBar Quasar plugin
      // ..and many more (check Installation card on each Quasar component/directive/plugin)
    },
  });

await BootInit({
  app,
  router,
  store,
});

app.mount('#app');
