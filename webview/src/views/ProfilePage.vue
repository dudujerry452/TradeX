<script setup>
import { onMounted, reactive } from 'vue'
import { RouterLink, useRouter } from 'vue-router'
import { clearLogin, getUser, getUserId } from '../utils/auth'
import { getUserTagPreferences } from '../config/api'

const router = useRouter()

const state = reactive({
  loading: true,
  user: null,
  tagPreferences: [],
})

const orderStats = [
  { label: '待付款', value: 2 },
  { label: '待发货', value: 1 },
  { label: '待收货', value: 3 },
  { label: '待评价', value: 0 },
]

const menuItems = [
  { title: '我的收藏', path: '/favorites' },
  { title: '消息通知', path: '/messages' },
  { title: '设置', path: '/home' },
]

const loadProfile = async () => {
  state.loading = true
  const user = await getUser()
  state.user = user

  if (user?.user_id) {
    const result = await getUserTagPreferences(user.user_id)
    state.tagPreferences = result.success && Array.isArray(result.data) ? result.data : []
  } else {
    state.tagPreferences = []
  }

  state.loading = false
}

const logout = async () => {
  await clearLogin()
  await router.push('/login')
}

onMounted(() => {
  loadProfile()
})
</script>

<template>
  <div class="profile-page">
    <section class="profile-card page-card">
      <div class="profile-hero">
        <div class="avatar">{{ state.user?.username?.slice(0, 1)?.toUpperCase() || 'U' }}</div>
        <div class="profile-copy">
          <p class="eyebrow">我的</p>
          <h2>{{ state.user?.username || '未登录' }}</h2>
          <p>{{ state.user?.email || '暂无邮箱信息' }}</p>
        </div>
        <RouterLink to="/login" class="secondary-btn" v-if="!state.user">去登录</RouterLink>
        <button v-else type="button" class="ghost-btn" @click="logout">退出登录</button>
      </div>

      <div class="stats-grid">
        <div v-for="item in orderStats" :key="item.label" class="stat-card">
          <strong>{{ item.value }}</strong>
          <span>{{ item.label }}</span>
        </div>
      </div>
    </section>

    <section class="profile-card page-card">
      <div class="section-head">
        <div>
          <p class="section-title">功能入口</p>
          <p class="section-subtitle">对齐 mobile 端“我的”页面中的常用功能块。</p>
        </div>
      </div>

      <div class="menu-grid">
        <RouterLink v-for="item in menuItems" :key="item.title" :to="item.path" class="menu-item">
          <span>{{ item.title }}</span>
        </RouterLink>
      </div>
    </section>

    <section class="profile-card page-card">
      <div class="section-head">
        <div>
          <p class="section-title">标签偏好</p>
          <p class="section-subtitle">推荐系统的偏好数据会在这里同步展示。</p>
        </div>
      </div>

      <article v-if="state.loading" class="status-card">正在加载个人信息...</article>
      <article v-else-if="!state.tagPreferences.length" class="status-card empty-state">
        <p>暂无标签偏好</p>
      </article>
      <div v-else class="tag-list">
        <div v-for="tag in state.tagPreferences" :key="tag.tag_id" class="tag-card">
          <strong>{{ tag.tag_name }}</strong>
          <span>分数 {{ Number(tag.score || 0).toFixed(1) }}</span>
        </div>
      </div>
    </section>

    <section class="profile-card page-card">
      <div class="section-head">
        <div>
          <p class="section-title">账号信息</p>
          <p class="section-subtitle">用户 ID、角色等基础数据。</p>
        </div>
      </div>

      <div class="info-grid">
        <div>
          <span>用户ID</span>
          <strong>{{ state.user?.user_id || '-' }}</strong>
        </div>
        <div>
          <span>角色</span>
          <strong>{{ state.user?.role || 'NORMAL' }}</strong>
        </div>
        <div>
          <span>注册状态</span>
          <strong>{{ state.user?.register_status || 'APPROVED' }}</strong>
        </div>
        <div>
          <span>收货地址</span>
          <strong>{{ state.user?.address || '-' }}</strong>
        </div>
      </div>
    </section>
  </div>
</template>

<style scoped>
.profile-page {
  display: grid;
  gap: 16px;
}

.profile-card {
  padding: 18px;
  display: grid;
  gap: 16px;
}

.profile-hero {
  display: grid;
  grid-template-columns: 72px minmax(0, 1fr) auto;
  gap: 14px;
  align-items: center;
}

.avatar {
  width: 72px;
  height: 72px;
  border-radius: 22px;
  display: grid;
  place-items: center;
  background: linear-gradient(135deg, var(--primary), var(--primary-strong));
  color: white;
  font-size: 28px;
  font-weight: 900;
}

.eyebrow {
  color: var(--primary);
  font-size: 13px;
  font-weight: 800;
  letter-spacing: 0.08em;
  text-transform: uppercase;
}

.profile-copy h2 {
  margin-top: 4px;
  font-size: 28px;
  font-weight: 900;
}

.profile-copy p:last-child {
  margin-top: 4px;
  color: var(--text-muted);
}

.stats-grid {
  display: grid;
  grid-template-columns: repeat(4, minmax(0, 1fr));
  gap: 10px;
}

.stat-card {
  padding: 14px;
  border-radius: 18px;
  background: rgba(17, 19, 31, 0.04);
  display: grid;
  gap: 4px;
  text-align: center;
}

.stat-card strong {
  font-size: 22px;
}

.stat-card span {
  font-size: 12px;
  color: var(--text-muted);
}

.menu-grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 12px;
}

.menu-item {
  padding: 16px;
  border-radius: 18px;
  background: rgba(17, 19, 31, 0.04);
  text-decoration: none;
  font-weight: 800;
}

.tag-list {
  display: flex;
  flex-wrap: wrap;
  gap: 10px;
}

.tag-card {
  display: grid;
  gap: 4px;
  padding: 14px 16px;
  border-radius: 18px;
  background: rgba(206, 150, 91, 0.12);
}

.tag-card strong {
  font-size: 14px;
}

.tag-card span,
.info-grid span {
  color: var(--text-muted);
  font-size: 12px;
}

.info-grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 12px;
}

.info-grid div {
  padding: 14px 16px;
  border-radius: 18px;
  background: rgba(17, 19, 31, 0.04);
  display: grid;
  gap: 4px;
}

.info-grid strong {
  font-size: 14px;
  line-height: 1.4;
}

.empty-state {
  text-align: center;
}

@media (max-width: 720px) {
  .profile-card {
    padding: 14px;
  }

  .profile-hero {
    grid-template-columns: 1fr;
    text-align: left;
  }

  .stats-grid,
  .menu-grid,
  .info-grid {
    grid-template-columns: 1fr 1fr;
  }

  .menu-item {
    text-align: center;
  }
}
</style>
