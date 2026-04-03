<script setup>
import { computed } from 'vue'
import { useRoute } from 'vue-router'

const route = useRoute()

const navItems = [
  {
    to: '/home',
    label: '发现',
    icon: '⌂',
  },
  {
    to: '/create',
    label: '发布',
    icon: '＋',
  },
  {
    to: '/messages',
    label: '消息',
    icon: '✉',
  },
  {
    to: '/profile',
    label: '我的',
    icon: '◌',
  },
]

const isActive = (path) => {
  if (path === '/home') {
    return route.path === '/' || route.path === '/home'
  }

  if (path === '/profile') {
    return route.path.startsWith('/profile') || route.path.startsWith('/favorites')
  }

  return route.path === path || route.path.startsWith(`${path}/`)
}

const activeTitle = computed(() => {
  if (route.path.startsWith('/create')) return '发布'
  if (route.path.startsWith('/messages')) return '消息'
  if (route.path.startsWith('/profile')) return '我的'
  if (route.path.startsWith('/favorites')) return '我的收藏'
  return '发现'
})
</script>

<template>
  <div class="shell">
    <header class="shell-topbar">
      <RouterLink to="/home" class="shell-branding" aria-label="tradeX 首页">
        <span class="shell-brand">tradeX</span>
      </RouterLink>

      <nav class="top-nav" aria-label="主导航">
        <RouterLink
          v-for="item in navItems"
          :key="item.to"
          :to="item.to"
          class="nav-item"
          :class="{ active: isActive(item.to) }"
        >
          <span class="nav-label">{{ item.label }}</span>
        </RouterLink>
      </nav>

      <div class="shell-actions">
        <span class="shell-context">{{ activeTitle }}</span>
        <RouterLink to="/profile" class="shell-action-link">我的</RouterLink>
      </div>
    </header>

    <main class="shell-main">
      <RouterView />
    </main>
  </div>
</template>

<style scoped>
.shell {
  min-height: 100vh;
  padding: 18px;
  background: linear-gradient(180deg, #f2f1f8 0%, #f7f6fc 100%);
  color: #11131f;
}

.shell-topbar {
  position: sticky;
  top: 0;
  z-index: 30;
  display: grid;
  grid-template-columns: 1fr auto 1fr;
  align-items: center;
  gap: 16px;
  margin: 0 auto 18px;
  max-width: 1180px;
  padding: 12px 18px;
  border-radius: 18px;
  background: rgba(255, 255, 255, 0.74);
  border: 1px solid rgba(17, 19, 31, 0.08);
  box-shadow: 0 12px 30px rgba(16, 24, 40, 0.08);
  backdrop-filter: blur(18px);
}

.shell-branding {
  justify-self: start;
  text-decoration: none;
}

.shell-brand {
  display: inline-flex;
  align-items: center;
  height: 34px;
  padding: 0 12px;
  border-radius: 999px;
  background: rgba(17, 19, 31, 0.04);
  color: #11131f;
  font-size: 13px;
  font-weight: 800;
  letter-spacing: 0.04em;
  text-transform: uppercase;
}

.shell-main {
  max-width: 1180px;
  margin: 0 auto;
}

.top-nav {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  gap: 28px;
  justify-self: center;
  width: auto;
}

.nav-item {
  position: relative;
  min-height: 28px;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  text-decoration: none;
  color: #4f5568;
  font-size: 14px;
  font-weight: 600;
  letter-spacing: -0.01em;
  transition: color 0.2s ease;
}

.nav-item.active {
  color: var(--primary);
}

.nav-item.active::after {
  content: '';
  position: absolute;
  left: 12%;
  right: 12%;
  bottom: -10px;
  height: 2px;
  border-radius: 999px;
  background: var(--primary);
}

.shell-actions {
  justify-self: end;
  display: inline-flex;
  align-items: center;
  gap: 12px;
}

.shell-context {
  color: #667085;
  font-size: 13px;
  font-weight: 600;
}

.shell-action-link {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  min-height: 34px;
  padding: 0 14px;
  border-radius: 999px;
  background: rgba(206, 150, 91, 0.12);
  color: var(--primary);
  text-decoration: none;
  font-weight: 700;
}

@media (max-width: 720px) {
  .shell {
    padding: 12px;
  }

  .shell-topbar {
    grid-template-columns: 1fr;
    justify-items: stretch;
    gap: 12px;
    margin-bottom: 14px;
  }

  .shell-branding,
  .shell-actions {
    justify-self: stretch;
  }

  .shell-actions {
    justify-content: space-between;
  }

  .top-nav {
    width: 100%;
    grid-template-columns: repeat(4, minmax(0, 1fr));
    gap: 12px;
    justify-self: stretch;
  }

  .nav-item {
    min-height: 32px;
    font-size: 13px;
  }
}
</style>
