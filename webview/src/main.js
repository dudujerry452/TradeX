import { createApp } from 'vue'
import './theme.css'
import App from './App.vue'
import router from './router'

const vueApp = createApp(App);
vueApp.use(router);
vueApp.mount('#app');
