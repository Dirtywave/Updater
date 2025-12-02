import { fileURLToPath, URL } from 'node:url';

import { defineConfig } from 'vite';
import vue from '@vitejs/plugin-vue';
import vueDevTools from 'vite-plugin-vue-devtools';
import { quasar, transformAssetUrls } from '@quasar/vite-plugin';

// import { unstableRolldownAdapter } from 'vite-bundle-analyzer';
// import { analyzer } from 'vite-bundle-analyzer';
import checker from 'vite-plugin-checker';
// import { viteSingleFile } from 'vite-plugin-singlefile';

const host = process.env.TAURI_DEV_HOST;

// https://vite.dev/config/
export default defineConfig({
  build: {
    // don't minify for debug builds
    minify: !process.env.TAURI_ENV_DEBUG ? 'esbuild' : false,

    // produce sourcemaps for debug builds
    sourcemap: !!process.env.TAURI_ENV_DEBUG,

    // target: {
    // browser: ["es2022", "firefox115", "chrome115", "safari14"],
    // node: "node20",
    // },

    rollupOptions: {
      plugins: [
        {
          name: 'test-custom-plugin',
          buildEnd() {
            this.info('In buildEnd hook');
            // Custom logic here
          },
        },
        // unstableRolldownAdapter(
        //   analyzer({
        //     analyzerMode: 'static',
        //   }),
        // ),
      ],
    },
  },

  // Prevent vite from obscuring rust errors
  clearScreen: false,

  // TODO: Integrate with secretspec or declare in .env
  define: {
    'import.meta.env.GITHUB_API_TOKEN': JSON.stringify(process.env.GITHUB_API_TOKEN),
    'import.meta.env.PINIA_STORE_PATH': JSON.stringify(process.env.PINIA_STORE_PATH),
  },

  // TODO: Revisit this explanation; does it make sense?
  // Env variables starting with the item of `envPrefix` will be
  // exposed in tauri's source code through `import.meta.env`.
  envPrefix: ['VITE_', 'TAURI_ENV_*'],

  plugins: [
    vue({
      template: { transformAssetUrls },
    }),
    vueDevTools(),

    // @quasar/plugin-vite options list:
    // https://github.com/quasarframework/quasar/blob/dev/vite-plugin/index.d.ts
    quasar({
      sassVariables: fileURLToPath(new URL('./src/css/quasar.variables.scss', import.meta.url)),
    }),
    checker({
      vueTsc: true,
      // eslint: {
      //   lintCommand: 'eslint -c ./eslint.config.js "./src*/**/*.{ts,js,mjs,cjs,vue}"',
      //   useFlatConfig: true,
      // },
    }),
    // viteSingleFile({}),
  ],

  resolve: {
    alias: {
      src: fileURLToPath(new URL('./src', import.meta.url)),
      ...Object.fromEntries(
        [
          'access',
          'assets',
          'boot',
          'components',
          'composables',
          'directives',
          'layouts',
          'pages',
          'stores',
          'types',
          'utils',
        ].map((dir) => [dir, fileURLToPath(new URL(`./src/${dir}`, import.meta.url))]),
      ),
    },
  },

  server: {
    hmr: host
      ? {
          protocol: 'ws',
          host,
          port: 1421,
        }
      : true,
    host: host || false,
    // https: true,
    open: false,
    port: 1420,
    // Tauri expects a fixed port, fail if that port is not available
    strictPort: true,
    watch: {
      // Tell vite to ignore watching `src-tauri`
      ignored: ['**/src-tauri/**'],
    },
  },
});
