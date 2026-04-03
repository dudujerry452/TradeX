<script setup>
import { onMounted, reactive } from 'vue'
import { useRoute, RouterLink } from 'vue-router'
import {
  addFavorite,
  checkFavorite,
  getProductDetail,
  getProductTags,
  getSimilarProducts,
  recordProductView,
  removeFavorite,
} from '../config/api'
import { getUserId } from '../utils/auth'

const route = useRoute()

const state = reactive({
  loading: true,
  error: '',
  product: null,
  tags: [],
  similarProducts: [],
  currentUserId: '',
  isFavorited: false,
  favoriteLoading: false,
})

const hideBrokenImage = (event) => {
  event.target.style.display = 'none'
}

const formatPrice = (value) => Number(value || 0).toFixed(2)

const loadData = async () => {
  const productId = route.params.productId
  if (!productId) {
    state.loading = false
    state.error = '缺少商品ID'
    return
  }

  state.loading = true
  state.error = ''

  try {
    const userId = await getUserId()
    state.currentUserId = userId || ''

    // 浏览记录失败不影响页面展示
    recordProductView(productId)

    const [productResult, tagsResult, similarResult, favoriteResult] = await Promise.all([
      getProductDetail(productId),
      getProductTags(productId),
      getSimilarProducts({ productId, limit: 6 }),
      userId ? checkFavorite(userId, productId) : Promise.resolve({ success: true, isFavorited: false }),
    ])

    if (!productResult.success) {
      throw new Error(productResult.message || '加载商品详情失败')
    }

    state.product = productResult.data
    state.tags = tagsResult.success && Array.isArray(tagsResult.data) ? tagsResult.data : []
    state.similarProducts =
      similarResult.success && Array.isArray(similarResult.data) ? similarResult.data : []
    state.isFavorited = favoriteResult.success ? Boolean(favoriteResult.isFavorited) : false
  } catch (error) {
    state.error = error instanceof Error ? error.message : '加载商品详情失败'
    state.product = null
    state.tags = []
    state.similarProducts = []
  } finally {
    state.loading = false
  }
}

const toggleFavorite = async () => {
  if (!state.currentUserId) {
    window.alert('请先登录')
    return
  }

  if (!state.product || state.favoriteLoading) return

  state.favoriteLoading = true
  try {
    const result = state.isFavorited
      ? await removeFavorite(state.currentUserId, state.product.product_id)
      : await addFavorite(state.currentUserId, state.product.product_id)

    if (result.success) {
      state.isFavorited = !state.isFavorited
    } else {
      window.alert(result.message || '操作失败')
    }
  } finally {
    state.favoriteLoading = false
  }
}

onMounted(() => {
  loadData()
})
</script>

<template>
  <div class="detail-page">
    <header class="detail-topbar page-card">
      <RouterLink to="/home" class="back-link">← 返回发现页</RouterLink>
      <button type="button" class="ghost-btn" @click="loadData">刷新</button>
    </header>

    <section v-if="state.loading" class="status-card">正在加载商品详情...</section>
    <section v-else-if="state.error" class="status-card status-error">{{ state.error }}</section>

    <template v-else-if="state.product">
      <section class="hero-card page-card">
        <div class="hero-media">
          <img
            v-if="state.product.image_url"
            :src="state.product.image_url"
            :alt="state.product.product_name"
            loading="lazy"
            @error="hideBrokenImage"
          />
        </div>

        <div class="hero-info">
          <p class="eyebrow">商品详情</p>
          <h1>{{ state.product.product_name }}</h1>
          <p class="subtitle">{{ state.product.category }}</p>

          <div class="price-row">
            <span class="price">¥{{ formatPrice(state.product.price) }}</span>
            <span v-if="Number(state.product.stock) > 0" class="stock stock-ok">
              库存 {{ state.product.stock }}
            </span>
            <span v-else class="stock stock-out">暂时缺货</span>
          </div>

          <p class="description">
            {{ state.product.description || '暂无商品描述' }}
          </p>

          <div class="stats-grid">
            <div class="stat-item">
              <span>评分</span>
              <strong>{{ Number(state.product.avg_rating || 0).toFixed(1) }}</strong>
            </div>
            <div class="stat-item">
              <span>销量</span>
              <strong>{{ state.product.sales_count }}</strong>
            </div>
            <div class="stat-item">
              <span>浏览</span>
              <strong>{{ state.product.view_count }}</strong>
            </div>
            <div class="stat-item">
              <span>收藏</span>
              <strong>{{ state.product.favorite_count }}</strong>
            </div>
          </div>
        </div>
      </section>

      <section v-if="state.tags.length" class="panel-card page-card">
        <p class="section-title">商品标签</p>
        <div class="tag-list">
          <span v-for="tag in state.tags" :key="tag.tag_id" class="tag">{{ tag.tag_name }}</span>
        </div>
      </section>

      <section class="panel-card page-card">
        <p class="section-title">商品描述</p>
        <p class="description long-text">
          {{ state.product.description || '暂无商品描述' }}
        </p>
      </section>

      <section v-if="state.similarProducts.length" class="panel-card page-card">
        <div class="section-head">
          <div>
            <p class="section-title">相似商品</p>
            <p class="section-subtitle">基于共同标签数量排序</p>
          </div>
          <span class="section-badge">推荐</span>
        </div>

        <div class="similar-list">
          <RouterLink
            v-for="item in state.similarProducts"
            :key="item.product_id"
            class="similar-card"
            :to="`/product/${item.product_id}`"
          >
            <div class="similar-media">
              <img
                v-if="item.image_url"
                :src="item.image_url"
                :alt="item.product_name"
                loading="lazy"
                @error="hideBrokenImage"
              />
            </div>
            <div class="similar-info">
              <strong>{{ item.product_name }}</strong>
              <span>¥{{ formatPrice(item.price) }}</span>
            </div>
          </RouterLink>
        </div>
      </section>

      <div class="bottom-spacer"></div>
      <footer class="action-bar page-card">
        <button type="button" class="icon-btn" :class="{ active: state.isFavorited }" @click="toggleFavorite">
          {{ state.favoriteLoading ? '...' : state.isFavorited ? '已收藏' : '收藏' }}
        </button>
        <button type="button" class="secondary-btn action-btn">加入购物车</button>
        <button type="button" class="primary-btn action-btn">立即购买</button>
      </footer>
    </template>
  </div>
</template>

<style scoped>
.detail-page {
  display: grid;
  gap: 16px;
  padding-bottom: 120px;
}

.detail-topbar {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  padding: 14px 16px;
}

.back-link {
  text-decoration: none;
  font-weight: 800;
  color: #11131f;
}

.hero-card {
  display: grid;
  grid-template-columns: minmax(0, 1fr) minmax(320px, 0.9fr);
  gap: 20px;
  padding: 18px;
}

.hero-media {
  min-height: 520px;
  border-radius: 18px;
  overflow: hidden;
  background: linear-gradient(135deg, rgba(206, 150, 91, 0.12), rgba(17, 19, 31, 0.04));
}

.hero-media img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}

.hero-info {
  display: grid;
  gap: 14px;
}

.eyebrow {
  color: var(--primary);
  font-size: 13px;
  font-weight: 800;
  letter-spacing: 0.08em;
  text-transform: uppercase;
}

.hero-info h1 {
  font-size: 38px;
  line-height: 1.08;
  letter-spacing: -0.04em;
  font-weight: 900;
}

.subtitle {
  color: var(--text-muted);
  font-size: 18px;
}

.price-row {
  display: flex;
  align-items: center;
  flex-wrap: wrap;
  gap: 10px;
}

.price {
  font-size: 34px;
  font-weight: 900;
  color: #11131f;
}

.stock {
  display: inline-flex;
  align-items: center;
  border-radius: 999px;
  padding: 6px 10px;
  font-size: 12px;
  font-weight: 800;
}

.stock-ok {
  color: #067647;
  background: rgba(6, 118, 71, 0.1);
}

.stock-out {
  color: #b42318;
  background: rgba(180, 35, 24, 0.1);
}

.description {
  color: var(--text-muted);
  font-size: 15px;
  line-height: 1.75;
}

.long-text {
  max-width: 72ch;
}

.stats-grid {
  display: grid;
  grid-template-columns: repeat(4, minmax(0, 1fr));
  gap: 10px;
}

.stat-item {
  padding: 14px;
  border-radius: 16px;
  background: rgba(17, 19, 31, 0.04);
  display: grid;
  gap: 4px;
}

.stat-item span {
  font-size: 12px;
  color: var(--text-muted);
}

.stat-item strong {
  font-size: 18px;
  color: #11131f;
}

.panel-card {
  padding: 18px;
  display: grid;
  gap: 14px;
}

.section-title {
  font-size: 22px;
  line-height: 1.1;
  font-weight: 900;
}

.section-subtitle {
  color: var(--text-muted);
  font-size: 13px;
}

.section-head {
  display: flex;
  align-items: end;
  justify-content: space-between;
  gap: 12px;
}

.section-badge {
  padding: 6px 10px;
  border-radius: 999px;
  background: rgba(206, 150, 91, 0.12);
  color: var(--primary);
  font-size: 12px;
  font-weight: 800;
}

.tag-list {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
}

.tag {
  display: inline-flex;
  align-items: center;
  padding: 7px 10px;
  border-radius: 999px;
  background: rgba(17, 19, 31, 0.05);
  color: #4f5568;
  font-size: 12px;
  font-weight: 700;
}

.similar-list {
  display: grid;
  grid-auto-flow: column;
  grid-auto-columns: 180px;
  gap: 12px;
  overflow-x: auto;
  padding-bottom: 4px;
}

.similar-card {
  text-decoration: none;
  color: inherit;
  display: grid;
  gap: 8px;
}

.similar-media {
  aspect-ratio: 1 / 1;
  overflow: hidden;
  border-radius: 16px;
  background: linear-gradient(135deg, rgba(206, 150, 91, 0.12), rgba(17, 19, 31, 0.04));
}

.similar-media img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}

.similar-info {
  display: grid;
  gap: 2px;
}

.similar-info strong {
  font-size: 14px;
  line-height: 1.4;
}

.similar-info span {
  font-size: 13px;
  color: var(--primary);
  font-weight: 800;
}

.bottom-spacer {
  height: 8px;
}

.action-bar {
  position: fixed;
  left: 50%;
  bottom: 16px;
  transform: translateX(-50%);
  width: min(1180px, calc(100vw - 24px));
  display: grid;
  grid-template-columns: 110px 1fr 1fr;
  gap: 12px;
  padding: 14px;
  z-index: 20;
}

.icon-btn {
  border: 0;
  border-radius: 14px;
  background: rgba(17, 19, 31, 0.06);
  color: #4f5568;
  font-weight: 800;
}

.icon-btn.active {
  background: rgba(206, 150, 91, 0.14);
  color: var(--primary);
}

.action-btn {
  min-height: 50px;
}

@media (max-width: 960px) {
  .hero-card {
    grid-template-columns: 1fr;
  }

  .hero-media {
    min-height: 360px;
  }

  .stats-grid {
    grid-template-columns: repeat(2, minmax(0, 1fr));
  }

  .action-bar {
    grid-template-columns: 96px 1fr 1fr;
  }
}

@media (max-width: 720px) {
  .hero-card,
  .panel-card,
  .detail-topbar {
    padding: 14px;
  }

  .hero-info h1 {
    font-size: 28px;
  }

  .subtitle {
    font-size: 16px;
  }

  .price {
    font-size: 28px;
  }

  .stats-grid {
    grid-template-columns: 1fr 1fr;
  }

  .similar-list {
    grid-auto-columns: 150px;
  }

  .action-bar {
    width: calc(100vw - 16px);
    bottom: 8px;
    grid-template-columns: 1fr;
  }
}
</style>
