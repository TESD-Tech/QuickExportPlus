import { defineConfig } from 'vite';
import { svelte } from '@sveltejs/vite-plugin-svelte';
import fs from 'fs';
import path from 'path';

// Get all .svelte files in the src/components directory
const components = fs.readdirSync(path.resolve(__dirname, 'src/components'))
  .filter(file => file.endsWith('.svelte'))
  .map(file => path.resolve(__dirname, 'src/components', file));

// https://vitejs.dev/config/
export default defineConfig({
  resolve: {
    alias: {
      $ps: path.resolve('./src/powerschool/WEB_ROOT')
    }
  },
  plugins: [
    svelte({
      compilerOptions: {
        customElement: true,
        // Enable run-time checks when not in production
        dev: true,
      },
    }),
  ],
  build: {
    target: 'esnext',
    outDir: 'dist/WEB_ROOT/is-QuickExportPlus/',
    assetsDir: '/assets',
    emptyOutDir: true,
    minify: true,
    rollupOptions: {
      input: components,
      output: {
        format: 'es',
        entryFileNames: '[name].js',
        chunkFileNames: '[name].js',
        assetFileNames: '[name].[ext]',
        exports: 'named',
        sourcemap: false,
        sourcemapExcludeSources: false,
        inlineDynamicImports: false,
      },
      plugins: [],
    },
  },
  server: {
    // Enable Hot Module Replacement during development
    hmr: {
      overlay: false,
    },
  },
});
