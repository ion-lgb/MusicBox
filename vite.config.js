import { defineConfig } from 'vite';
import vue from '@vitejs/plugin-vue';

export default defineConfig({
  plugins: [vue()],
  // Tauri dev server
  server: {
    host: '127.0.0.1',
    port: 5173,
    strictPort: true,
  },
  // 确保打包后路径正确
  base: './',
});
