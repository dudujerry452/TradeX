<template>
  <div class="admin-shell">
    <aside class="sidebar">
      <div class="sidebar-brand">
        <div class="brand-mark">TX</div>
        <div>
          <h1>TradeX Admin</h1>
          <p>后台管理中心</p>
        </div>
      </div>

      <nav class="nav-list">
        <router-link
          v-for="item in navItems"
          :key="item.to"
          :to="item.to"
          class="nav-link"
        >
          <span class="nav-dot"></span>
          <div>
            <strong>{{ item.label }}</strong>
            <small>{{ item.desc }}</small>
          </div>
        </router-link>
      </nav>

      <div class="sidebar-footer">
        <span class="chip chip--soft">API 复用模式</span>
        <p>仅管理员可进入后台。</p>
      </div>
    </aside>

    <div class="content-shell">
      <header class="topbar">
        <div>
          <p class="eyebrow">TradeX 后台</p>
          <h2>{{ currentTitle }}</h2>
        </div>

        <div class="topbar-actions">
          <span class="chip chip--accent">管理员</span>
          <span class="user-badge">{{ username }}</span>
          <button class="ghost-btn" type="button" @click="handleLogout">退出</button>
        </div>
      </header>

      <main class="page-shell">
        <router-view />
      </main>
    </div>
  </div>
</template>

<script setup>
import { computed, onMounted, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'

import { clearLogin, getUser } from '../services/auth'

const router = useRouter()
const route = useRoute()
const username = ref('管理员')

const navItems = [
  { to: '/dashboard', label: '仪表盘', desc: '总览与待处理事项' },
  { to: '/users', label: '用户管理', desc: '审核与角色管理' },
  { to: '/products', label: '商品审核', desc: '商品审核与上下架' },
  { to: '/orders', label: '订单处理', desc: '查看与推进订单状态' },
]

const currentTitle = computed(() => route.matched.at(-1)?.meta?.title || '后台管理')

const handleLogout = async () => {
  await clearLogin()
  await router.push('/login')
}

onMounted(async () => {
  const user = await getUser()
  if (user?.username) {
    username.value = user.username
  }
})
</script>
