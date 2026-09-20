import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import { fileURLToPath } from 'node:url';

const local = (path: string) => fileURLToPath(new URL(path, import.meta.url));
export default defineConfig({
  root: local('./mobile/'),
  base: '/',
  publicDir: local('./public/'),
  plugins: [react()],
  resolve: { alias: { 'next/link': local('./mobile/link.tsx') } },
  css: { postcss: local('./') },
  build: {
    outDir: local('./dist-mobile/'),
    emptyOutDir: true,
    target: 'es2020',
  },
});
