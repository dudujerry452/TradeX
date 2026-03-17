import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'

// https://vite.dev/config/
export default defineConfig({
  plugins: [vue()],
  base: '/static/',
  server: {
    proxy: {
      // 假设你 Django 提供的接口都以 /api 开头
      '/api': {
        target: 'http://127.0.0.1:8000', // Django 服务的地址
        changeOrigin: true,
      }
    }
  }
})
