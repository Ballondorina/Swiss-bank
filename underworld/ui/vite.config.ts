import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import { resolve } from 'path'

export default defineConfig({
  plugins: [react()],
  base: './',
  build: {
    outDir: resolve(__dirname, '../web/dist'),
    emptyOutDir: true,
    rollupOptions: {
      output: {
        // Single chunk for FiveM compatibility
        manualChunks: undefined,
      },
    },
  },
  server: {
    port: 3000,
    open: true,
  },
})
