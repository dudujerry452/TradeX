import { createRouter, createWebHistory } from 'vue-router'

import AdminLayout from '../layouts/AdminLayout.vue'
import DashboardView from '../views/DashboardView.vue'
import LoginView from '../views/LoginView.vue'
import OrdersView from '../views/OrdersView.vue'
import ProductsView from '../views/ProductsView.vue'
import UsersView from '../views/UsersView.vue'
import { clearLogin, getUser, isAdminLoggedIn } from '../services/auth'

const routes = [
  {
    path: '/login',
    name: 'AdminLogin',
    component: LoginView,
  },
  {
    path: '/',
    component: AdminLayout,
    meta: { requiresAuth: true },
    children: [
      {
        path: '',
        redirect: '/dashboard',
      },
      {
        path: 'dashboard',
        name: 'AdminDashboard',
        component: DashboardView,
        meta: { requiresAuth: true, title: '仪表盘' },
      },
      {
        path: 'users',
        name: 'AdminUsers',
        component: UsersView,
        meta: { requiresAuth: true, title: '用户管理' },
      },
      {
        path: 'products',
        name: 'AdminProducts',
        component: ProductsView,
        meta: { requiresAuth: true, title: '商品审核' },
      },
      {
        path: 'orders',
        name: 'AdminOrders',
        component: OrdersView,
        meta: { requiresAuth: true, title: '订单处理' },
      },
    ],
  },
  {
    path: '/:pathMatch(.*)*',
    redirect: '/dashboard',
  },
]

const router = createRouter({
  history: createWebHistory(import.meta.env.BASE_URL),
  routes,
})

router.beforeEach(async (to) => {
  if (to.path === '/login') {
    const loggedIn = await isAdminLoggedIn()
    if (loggedIn) {
      return '/dashboard'
    }
    return true
  }

  const requiresAuth = to.matched.some((record) => record.meta?.requiresAuth)
  if (!requiresAuth) {
    return true
  }

  const loggedIn = await isAdminLoggedIn()
  if (!loggedIn) {
    return {
      path: '/login',
      query: { redirect: to.fullPath },
    }
  }

  const user = await getUser()
  if (user?.role !== 'ADMIN') {
    await clearLogin()
    return {
      path: '/login',
      query: { reason: 'forbidden' },
    }
  }

  return true
})

export default router
