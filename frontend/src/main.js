import { createApp } from 'vue'
import './style.css'
import App from './App.vue'
import router from './router'

const vueApp = createApp(App);
vueApp.use(router);
vueApp.mount('#app');
