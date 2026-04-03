<script setup>
import { onMounted, reactive } from 'vue'
import { RouterLink, useRouter } from 'vue-router'
import { getUserFavorites, removeFavorite } from '../config/api'
import { getUserId } from '../utils/auth'

const router = useRouter()

const state = reactive({
  loading: true,
  currentUserId: '',
  favorites: [],
  error: '',
})

const loadFavorites = async () => {
  state.loading = true
  state.error = ''

  try {
    const userId = await getUserId()
    state.currentUserId = userId || ''

    if (!state.currentUserId) {
      state.favorites = []
      state.error = '请先登录'
      return
    }

    const result = await getUserFavorites(state.currentUserId)
    if (result.success) {
      state.favorites = Array.isArray(result.data) ? result.data : []
    } else {
      state.error = result.message || '获取收藏失败'
    }
  } finally {
    state.loading = false
  }
}

const deleteFavorite = async (productId) => {
  if (!state.currentUserId) return

  const result = await removeFavorite(state.currentUserId, productId)
  if (result.success) {
    state.favorites = state.favorites.filter((item) => item.product_id !== productId)
  } else {
    window.alert(result.message || '取消收藏失败')
  }
}

onMounted(() => {
  loadFavorites()
})
</script>

<template>
  <div class="favorites-page">
    <section class="favorites-card page-card">
      <div class="favorites-head">
        <div>
          <p class="section-title">我的收藏</p>
          <p class="section-subtitle">与 mobile 端一致的收藏列表和取消收藏能力。</p>
        </div>
        <button type="button" class="ghost-btn" @click="loadFavorites">刷新</button>
      </div>

      <article v-if="state.loading" class="status-card">正在加载收藏列表...</article>
      <article v-else-if="state.error && !state.currentUserId" class="status-card status-error">
        {{ state.error }}
        <div class="action-row">
          <RouterLink to="/login" class="primary-btn">前往登录</RouterLink>
        </div>
      </article>
      <article v-else-if="state.error" class="status-card status-error">
        {{ state.error }}
      </article>

      <article v-else-if="!state.favorites.length" class="status-card empty-state">
        <p>暂无收藏商品</p>
        <RouterLink to="/home" class="secondary-btn">去发现页看看</RouterLink>
      </article>

      <div v-else class="favorite-list">
        <RouterLink
          v-for="favorite in state.favorites"
          :key="favorite.product_id"
          class="favorite-card"
          :to="`/product/${favorite.product_id}`"
        >
          <div class="favorite-media">
            <img
              v-if="favorite.image_url"
              :src="favorite.image_url"
              :alt="favorite.product_name"
              loading="lazy"
            />
          </div>
          <div class="favorite-info">
            <div>
              <h4>{{ favorite.product_name }}</h4>
              <p>¥{{ Number(favorite.price || 0).toFixed(2) }}</p>
            </div>
            <button
              type="button"
              class="ghost-btn delete-btn"
              @click.prevent="deleteFavorite(favorite.product_id)"
            >
              取消收藏
            </button>
          </div>
        </RouterLink>
      </div>

      <div class="footer-actions">
        <button type="button" class="ghost-btn" @click="router.push('/profile')">返回我的页面</button>
      </div>
    </section>
  </div>
</template>

<style scoped>
.favorites-page {
  display: grid;
  gap: 16px;
}

.favorites-card {
  padding: 18px;
  display: grid;
  gap: 16px;
}

.favorites-head {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 14px;
}

.favorite-list {
  display: grid;
  gap: 12px;
}

.favorite-card {
  display: grid;
  grid-template-columns: 120px minmax(0, 1fr);
  gap: 12px;
  text-decoration: none;
  color: inherit;
  padding: 12px;
  border-radius: 18px;
  background: rgba(17, 19, 31, 0.04);
}

.favorite-media {
  aspect-ratio: 1 / 1;
  overflow: hidden;
  border-radius: 14px;
  background: linear-gradient(135deg, rgba(206, 150, 91, 0.12), rgba(17, 19, 31, 0.04));
}

.favorite-media img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}

.favorite-info {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
}

.favorite-info h4 {
  font-size: 16px;
  line-height: 1.4;
}

.favorite-info p {
  margin-top: 6px;
  color: var(--primary);
  font-weight: 800;
}

.delete-btn {
  padding-inline: 12px;
  white-space: nowrap;
}

.empty-state {
  text-align: center;
  display: grid;
  place-items: center;
  gap: 12px;
}

.action-row,
.footer-actions {
  display: flex;
  justify-content: center;
}

@media (max-width: 720px) {
  .favorites-card {
    padding: 14px;
  }

  .favorites-head {
    flex-direction: column;
  }

  .favorite-card {
    grid-template-columns: 1fr;
  }

  .favorite-info {
    flex-direction: column;
    align-items: flex-start;
  }

  .delete-btn {
    width: 100%;
  }
}
</style>
