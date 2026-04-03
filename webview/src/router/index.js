import { createRouter, createWebHistory } from 'vue-router'
import MainShell from '../components/MainShell.vue'
import { isLoggedIn } from '../utils/auth'
import UserLogin from '../views/UserLogin.vue'
import RegisterPage from '../views/RegisterPage.vue'
import HomePage from '../views/HomePage.vue'
import ProductPage from '../views/ProductPage.vue'
import CreateProductPage from '../views/CreateProductPage.vue'
import MessagePage from '../views/MessagePage.vue'
import ProfilePage from '../views/ProfilePage.vue'
import FavoritesPage from '../views/FavoritesPage.vue'

const routes = [
  {
    path: '/login',
    name: 'UserLogin',
    component: UserLogin,
  },
  {
    path: '/register',
    name: 'RegisterPage',
    component: RegisterPage,
  },
  {
    path: '/',
    component: MainShell,
    children: [
      {
        path: '',
        name: 'HomePage',
        component: HomePage,
        alias: '/home',
      },
      {
        path: 'create',
        name: 'CreateProductPage',
        component: CreateProductPage,
        meta: { requiresAuth: true },
      },
      {
        path: 'messages',
        name: 'MessagePage',
        component: MessagePage,
      },
      {
        path: 'profile',
        name: 'ProfilePage',
        component: ProfilePage,
        meta: { requiresAuth: true },
      },
      {
        path: 'favorites',
        name: 'FavoritesPage',
        component: FavoritesPage,
        meta: { requiresAuth: true },
      },
    ],
  },
  {
    path: '/product/:productId?',
    name: 'ProductPage',
    component: ProductPage,
  },
  {
    path: '/:pathMatch(.*)*',
    redirect: '/home',
  },
]

const router = createRouter({
  history: createWebHistory(import.meta.env.BASE_URL),
  routes,
})

router.beforeEach(async (to) => {
  if (to.path === '/') {
    return '/login'
  }

  const requiresAuth = to.matched.some((record) => record.meta?.requiresAuth)
  if (!requiresAuth) {
    return true
  }

  const loggedIn = await isLoggedIn()
  if (loggedIn) {
    return true
  }

  return {
    path: '/login',
    query: { redirect: to.fullPath },
  }
})

export default router
