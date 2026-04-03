<script setup>
import { computed, onBeforeUnmount, onMounted, reactive, ref } from 'vue'
import { RouterLink } from 'vue-router'
import RagChatPanel from '../components/RagChatPanel.vue'
import {
  getCategories,
  getPersonalizedRecommendations,
  getTrendingRecommendations,
  searchProducts,
} from '../config/api'
import { getUserId } from '../utils/auth'

const pageSize = 8

const tabs = [
  { key: 'follow', label: '关注' },
  { key: 'recommend', label: '推荐' },
  { key: 'latest', label: '最新' },
  { key: 'discuss', label: '讨论' },
]

const state = reactive({
  loading: false,
  loadingMore: false,
  error: '',
  products: [],
  categories: [],
  selectedCategory: 'all',
  activeTab: 'recommend',
  searchQuery: '',
  isSearching: false,
  hasMore: true,
  offset: 0,
})

const showAiPanel = ref(true)

const featuredProduct = computed(() => state.products[0] || null)
const activeTabLabel = computed(() => tabs.find((item) => item.key === state.activeTab)?.label || '推荐')
const visibleProductCount = computed(() => state.products.length)
const categoryCount = computed(() => state.categories.length)

const hideBrokenImage = (event) => {
  event.target.style.display = 'none'
}

const normalizeProducts = (items) => (Array.isArray(items) ? items : [])

const fetchCategories = async () => {
  const result = await getCategories()
  if (result.success) {
    state.categories = Array.isArray(result.data) ? result.data : []
  }
}

const setPlaceholderState = () => {
  state.products = []
  state.hasMore = false
}

const fetchCurrentProducts = async ({ refresh = false } = {}) => {
  if (state.loading && !refresh) return

  if (refresh) {
    state.offset = 0
    state.hasMore = true
    state.products = []
  }

  state.loading = true
  state.error = ''

  try {
    let items = []
    const limit = pageSize
    const offset = state.offset
    const category = state.selectedCategory === 'all' ? undefined : state.selectedCategory
    const keyword = state.searchQuery.trim()

    if (!keyword && (state.activeTab === 'follow' || state.activeTab === 'discuss')) {
      setPlaceholderState()
      return
    }

    if (keyword) {
      const result = await searchProducts({
        query: keyword,
        category,
        limit,
        offset,
      })
      if (!result.success) throw new Error(result.message || '搜索失败')
      items = normalizeProducts(result.data)
    } else if (state.activeTab === 'recommend') {
      if (category) {
        const result = await searchProducts({
          query: '',
          category,
          limit,
          offset,
        })
        if (!result.success) throw new Error(result.message || '获取推荐失败')
        items = normalizeProducts(result.data)
      } else {
        const userId = await getUserId()
        const result = userId
          ? await getPersonalizedRecommendations({ userId, limit, offset })
          : await getTrendingRecommendations({ limit, offset })

        if (!result.success) throw new Error(result.message || '获取推荐失败')
        items = normalizeProducts(result.data)
      }
    } else if (state.activeTab === 'latest') {
      const result = await searchProducts({
        query: '',
        category,
        limit,
        offset,
      })
      if (!result.success) throw new Error(result.message || '获取商品失败')
      items = normalizeProducts(result.data)
    }

    if (offset === 0) {
      state.products = items
    } else {
      state.products = [...state.products, ...items]
    }

    state.hasMore = items.length >= limit
  } catch (error) {
    state.error = error instanceof Error ? error.message : '加载商品失败'
    state.products = []
    state.hasMore = false
  } finally {
    state.loading = false
    state.loadingMore = false
  }
}

const refreshProducts = async () => {
  await fetchCurrentProducts({ refresh: true })
}

const loadMoreProducts = async () => {
  if (state.loadingMore || state.loading || !state.hasMore) return

  state.loadingMore = true
  state.offset += pageSize
  await fetchCurrentProducts()
}

const performSearch = async () => {
  state.isSearching = true
  state.offset = 0
  state.hasMore = true
  await fetchCurrentProducts({ refresh: true })
}

const clearSearch = async () => {
  state.searchQuery = ''
  state.isSearching = false
  await refreshProducts()
}

const selectTab = async (tabKey) => {
  state.activeTab = tabKey
  state.offset = 0
  state.hasMore = true
  if (!state.searchQuery.trim()) {
    await refreshProducts()
  } else {
    await fetchCurrentProducts({ refresh: true })
  }
}

const selectCategory = async (categoryId) => {
  state.selectedCategory = categoryId
  state.offset = 0
  state.hasMore = true
  await fetchCurrentProducts({ refresh: true })
}

const toggleAiPanel = () => {
  showAiPanel.value = !showAiPanel.value
}

const onWindowScroll = () => {
  const scrollBottom = window.innerHeight + window.scrollY
  const pageHeight = document.documentElement.scrollHeight
  if (scrollBottom >= pageHeight - 240) {
    loadMoreProducts()
  }
}

onMounted(async () => {
  await Promise.all([fetchCategories(), refreshProducts()])
  window.addEventListener('scroll', onWindowScroll, { passive: true })
})

onBeforeUnmount(() => {
  window.removeEventListener('scroll', onWindowScroll)
})
</script>

<template>
  <div class="discover-page">
    <section class="hero-card page-card">
      <div class="hero-copy">
        <p class="eyebrow">tradeX 发现页</p>
        <h2 class="hero-title">更像网页首页的商品发现中心</h2>
        <p class="hero-desc">
          这里把搜索、推荐、分类和 AI 导购放进统一的信息架构里，减少 App 式的大块堆叠，改成更符合桌面端浏览习惯的布局。
        </p>

        <div class="hero-metrics">
          <div class="metric-card">
            <span>当前展示</span>
            <strong>{{ visibleProductCount }}</strong>
          </div>
          <div class="metric-card">
            <span>分类数量</span>
            <strong>{{ categoryCount }}</strong>
          </div>
          <div class="metric-card">
            <span>当前标签</span>
            <strong>{{ activeTabLabel }}</strong>
          </div>
        </div>
      </div>

      <div class="hero-panel page-card">
        <div class="search-shell input-shell">
          <span class="search-icon" aria-hidden="true">⌕</span>
          <input
            v-model="state.searchQuery"
            type="text"
            placeholder="搜索商品、品牌或关键词"
            @keydown.enter.prevent="performSearch"
          />
          <button v-if="state.searchQuery" type="button" class="clear-btn" @click="clearSearch">
            清除
          </button>
        </div>

        <div class="hero-actions">
          <button type="button" class="primary-btn" @click="performSearch">搜索</button>
          <button type="button" class="secondary-btn" @click="toggleAiPanel">
            {{ showAiPanel ? '收起 AI' : 'AI 导购' }}
          </button>
          <button type="button" class="ghost-btn" @click="refreshProducts">刷新推荐</button>
        </div>
      </div>
    </section>

    <section class="support-grid">
      <section class="category-card page-card">
        <div class="category-head">
          <div>
            <p class="section-title">分类</p>
            <p class="section-subtitle">按类目切换推荐和搜索结果</p>
          </div>
        </div>
        <div class="category-list">
          <button
            v-for="category in state.categories"
            :key="category.id"
            type="button"
            class="category-chip"
            :class="{ active: state.selectedCategory === category.id }"
            @click="selectCategory(category.id)"
          >
            {{ category.name }}
          </button>
        </div>
      </section>

      <section class="info-card page-card">
        <p class="section-title">浏览建议</p>
        <ul class="info-list">
          <li>推荐页会根据登录态返回个性化结果，未登录时会切到热门推荐。</li>
          <li>搜索结果更适合配合分类筛选一起使用，减少无关内容干扰。</li>
          <li>点击商品卡片可以直接进入详情页，适合桌面端快速浏览。</li>
        </ul>
      </section>

      <section v-if="showAiPanel" class="ai-card page-card ai-panel">
        <div class="ai-panel-head">
          <div>
            <p class="section-title">AI 导购</p>
            <p class="section-subtitle">根据商品知识库给出选购建议</p>
          </div>
          <button type="button" class="ghost-btn ai-toggle-btn" @click="toggleAiPanel">
            {{ showAiPanel ? '收起' : '展开' }}
          </button>
        </div>
        <RagChatPanel />
      </section>
    </section>

    <div class="content-layout">
      <main class="content-main">
        <section class="tabs-card page-card">
          <div class="tab-row">
            <button
              v-for="tab in tabs"
              :key="tab.key"
              type="button"
              class="tab-btn"
              :class="{ active: state.activeTab === tab.key }"
              @click="selectTab(tab.key)"
            >
              {{ tab.label }}
            </button>
          </div>
        </section>

        <section v-if="featuredProduct" class="featured-card page-card">
          <div class="featured-media">
            <img
              v-if="featuredProduct.image_url"
              :src="featuredProduct.image_url"
              :alt="featuredProduct.product_name"
              loading="lazy"
              @error="hideBrokenImage"
            />
          </div>
          <div class="featured-info">
            <p class="section-subtitle">当前推荐</p>
            <h3>{{ featuredProduct.product_name }}</h3>
            <p class="featured-category">{{ featuredProduct.category }} · 库存 {{ featuredProduct.stock }}</p>
            <p class="featured-desc">
              {{ featuredProduct.description }}
            </p>
            <div class="featured-meta">
              <span class="price">¥{{ Number(featuredProduct.price || 0).toFixed(2) }}</span>
              <span v-if="featuredProduct.relevance_score != null" class="meta-pill">
                相关度 {{ Number(featuredProduct.relevance_score).toFixed(2) }}
              </span>
              <span v-if="featuredProduct.is_favorited" class="meta-pill meta-pill-accent">已收藏</span>
            </div>
            <RouterLink class="primary-btn featured-link" :to="`/product/${featuredProduct.product_id}`">
              查看详情
            </RouterLink>
          </div>
        </section>

        <section class="feed-card page-card">
          <div class="feed-head">
            <div>
              <p class="section-title">
                {{ state.isSearching ? `“${state.searchQuery}” 的搜索结果` : activeTabLabel }}
              </p>
              <p class="section-subtitle">保留原有的数据链路，但把结果区改成更适合桌面端浏览的卡片网格。</p>
            </div>
            <button v-if="state.isSearching" type="button" class="ghost-btn" @click="clearSearch">
              清除搜索
            </button>
          </div>

          <article v-if="state.loading && !state.products.length" class="status-card">
            正在加载商品数据...
          </article>

          <article v-else-if="state.error" class="status-card status-error">
            {{ state.error }}
          </article>

          <article
            v-else-if="!state.products.length && !state.loading"
            class="status-card empty-state"
          >
            <p>{{ state.isSearching ? '未找到相关商品' : '当前暂无商品数据' }}</p>
            <button v-if="state.isSearching" type="button" class="secondary-btn" @click="clearSearch">
              清除搜索
            </button>
          </article>

          <div v-else class="product-grid">
            <RouterLink
              v-for="item in state.products"
              :key="item.product_id"
              class="product-card page-card"
              :to="`/product/${item.product_id}`"
            >
              <div class="product-media">
                <img
                  v-if="item.image_url"
                  :src="item.image_url"
                  :alt="item.product_name"
                  loading="lazy"
                  @error="hideBrokenImage"
                />
              </div>
              <div class="product-body">
                <div class="product-topline">
                  <h4>{{ item.product_name }}</h4>
                  <div class="price-line">
                    <span class="price">¥{{ Number(item.price || 0).toFixed(2) }}</span>
                    <span v-if="item.relevance_score != null" class="relevance-debug" title="DEBUG: 用户关联度评分">
                      [R:{{ Number(item.relevance_score).toFixed(2) }}]
                    </span>
                  </div>
                </div>
                <p class="product-meta">{{ item.category }} · 库存 {{ item.stock }}</p>
                <p class="product-desc">{{ item.description }}</p>
                <div class="product-tags">
                  <span v-if="item.relevance_score != null" class="tag">相关度 {{ Number(item.relevance_score).toFixed(2) }}</span>
                  <span v-if="item.is_favorited" class="tag tag-accent">已收藏</span>
                  <span class="tag">销量 {{ item.sales_count }}</span>
                  <span class="tag">浏览 {{ item.view_count }}</span>
                </div>
              </div>
            </RouterLink>
          </div>

          <div v-if="state.loadingMore" class="load-more-state">
            正在加载更多...
          </div>
          <button
            v-else-if="state.hasMore && state.products.length"
            type="button"
            class="ghost-btn load-more-btn"
            @click="loadMoreProducts"
          >
            加载更多
          </button>
        </section>

      </main>
    </div>
  </div>
</template>

<style scoped>
.discover-page {
  display: grid;
  gap: 20px;
  max-width: 1440px;
  margin: 0 auto;
}

.support-grid {
  display: grid;
  grid-template-columns: minmax(0, 1.1fr) minmax(0, 0.9fr);
  gap: 18px;
}

.hero-card,
.tabs-card,
.category-card,
.feed-card,
.featured-card,
.ai-card {
  padding: 18px;
}

.hero-card {
  display: grid;
  grid-template-columns: minmax(0, 1.2fr) minmax(360px, 0.9fr);
  gap: 20px;
  align-items: stretch;
  padding: 22px;
  background:
    radial-gradient(circle at top right, rgba(206, 150, 91, 0.12), transparent 28%),
    linear-gradient(145deg, rgba(255, 255, 255, 0.98), rgba(247, 246, 252, 0.94));
}

.hero-copy {
  display: grid;
  align-content: start;
  gap: 16px;
  padding: 8px 0;
}

.eyebrow {
  margin-bottom: 8px;
  color: var(--primary);
  font-size: 13px;
  font-weight: 800;
  letter-spacing: 0.08em;
  text-transform: uppercase;
}

.hero-title {
  font-size: 34px;
  line-height: 1.05;
  letter-spacing: -0.04em;
  font-weight: 900;
  max-width: 16ch;
}

.hero-desc {
  color: var(--text-muted);
  font-size: 14px;
  line-height: 1.7;
  max-width: 66ch;
}

.hero-metrics {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 12px;
}

.metric-card {
  display: grid;
  gap: 8px;
  padding: 16px;
  border-radius: 18px;
  background: rgba(255, 255, 255, 0.78);
  border: 1px solid rgba(17, 19, 31, 0.08);
  box-shadow: 0 14px 30px rgba(16, 24, 40, 0.04);
}

.metric-card span {
  color: var(--text-muted);
  font-size: 13px;
}

.metric-card strong {
  font-size: 20px;
  line-height: 1.1;
  font-weight: 900;
  color: var(--text);
}

.hero-panel {
  display: grid;
  gap: 14px;
  align-self: stretch;
  padding: 18px;
  border-radius: 22px;
  background: rgba(255, 255, 255, 0.9);
  border: 1px solid rgba(17, 19, 31, 0.08);
}

.hero-actions {
  width: 100%;
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 10px;
}

.search-shell {
  display: flex;
  align-items: center;
  gap: 10px;
  min-height: 58px;
  padding: 0 14px;
}

.search-icon {
  font-size: 18px;
  color: var(--text-muted);
}

.search-shell input {
  flex: 1;
  min-width: 0;
  border: 0;
  outline: none;
  background: transparent;
  font-size: 15px;
  color: var(--text);
}

.clear-btn {
  border: 0;
  background: transparent;
  color: var(--primary);
  font-weight: 700;
  padding: 0;
}

.hero-buttons {
  display: flex;
  flex-wrap: wrap;
  gap: 10px;
}

.tabs-card {
  padding: 14px 18px;
}

.tab-row {
  display: grid;
  grid-template-columns: repeat(4, minmax(0, 1fr));
  gap: 8px;
}

.tab-btn {
  border: 0;
  min-height: 46px;
  border-radius: 14px;
  background: rgba(17, 19, 31, 0.04);
  color: #4f5568;
  font-weight: 800;
}

.tab-btn.active {
  background: rgba(206, 150, 91, 0.14);
  color: var(--primary);
}

.category-card,
.feed-card,
.featured-card,
.ai-card {
  display: grid;
  gap: 16px;
}

.content-layout {
  display: grid;
  gap: 20px;
  align-items: start;
}

.content-main {
  display: grid;
  gap: 16px;
}

.category-head,
.feed-head {
  display: flex;
  align-items: flex-end;
  justify-content: space-between;
  gap: 12px;
}

.category-list {
  display: flex;
  flex-wrap: wrap;
  gap: 10px;
}

.category-chip {
  border: 1px solid rgba(17, 19, 31, 0.08);
  background: #fff;
  color: #4f5568;
  border-radius: 999px;
  padding: 10px 16px;
  font-size: 13px;
  font-weight: 700;
}

.category-chip.active {
  background: rgba(206, 150, 91, 0.12);
  color: var(--primary);
  border-color: rgba(206, 150, 91, 0.2);
}

.featured-card {
  grid-template-columns: minmax(0, 0.8fr) minmax(0, 1.2fr);
  align-items: center;
}

.featured-media {
  min-height: 320px;
  border-radius: 18px;
  overflow: hidden;
  background: linear-gradient(135deg, rgba(206, 150, 91, 0.12), rgba(17, 19, 31, 0.04));
}

.featured-media img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}

.featured-info {
  display: grid;
  gap: 12px;
}

.featured-info h3 {
  font-size: 28px;
  line-height: 1.08;
  letter-spacing: -0.03em;
}

.featured-category,
.featured-desc,
.product-desc,
.product-meta {
  color: var(--text-muted);
}

.featured-desc,
.product-desc {
  font-size: 14px;
  line-height: 1.65;
}

.featured-meta,
.product-tags {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
}

.featured-link {
  width: fit-content;
}

.price {
  font-weight: 900;
  color: #11131f;
}

.meta-pill,
.tag {
  display: inline-flex;
  align-items: center;
  border-radius: 999px;
  padding: 6px 10px;
  background: rgba(17, 19, 31, 0.05);
  font-size: 12px;
  font-weight: 700;
  color: #4f5568;
}

.meta-pill-accent,
.tag-accent {
  background: rgba(206, 150, 91, 0.12);
  color: var(--primary);
}

.product-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(240px, 1fr));
  gap: 16px;
}

.product-card {
  display: grid;
  gap: 12px;
  text-decoration: none;
  overflow: hidden;
  color: inherit;
  transition: transform 0.2s ease, box-shadow 0.2s ease;
}

.product-card:hover {
  transform: translateY(-2px);
  box-shadow: 0 22px 42px rgba(16, 24, 40, 0.12);
}

.product-media {
  aspect-ratio: 1 / 0.78;
  overflow: hidden;
  background: linear-gradient(135deg, rgba(206, 150, 91, 0.12), rgba(17, 19, 31, 0.04));
}

.product-media img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}

.product-body {
  display: grid;
  gap: 8px;
  padding: 0 4px 4px;
}

.product-topline {
  display: flex;
  align-items: start;
  justify-content: space-between;
  gap: 10px;
}

.price-line {
  display: flex;
  align-items: center;
  gap: 8px;
  flex-shrink: 0;
}

.relevance-debug {
  font-size: 11px;
  color: #ff6b6b;
  background: rgba(255, 107, 107, 0.1);
  padding: 2px 6px;
  border-radius: 4px;
  font-family: monospace;
  font-weight: 600;
  cursor: help;
}

.product-meta {
  font-size: 13px;
}

.empty-state {
  text-align: center;
  display: grid;
  place-items: center;
  gap: 12px;
}

.load-more-state {
  text-align: center;
  color: var(--text-muted);
  font-size: 13px;
}

.load-more-btn {
  width: 100%;
}

.ai-card {
  overflow: hidden;
}

.info-card {
  display: grid;
  gap: 14px;
  padding: 18px;
}

.ai-panel {
  grid-column: 1 / -1;
  display: grid;
  gap: 14px;
}

.ai-panel-head {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 12px;
}

.ai-toggle-btn {
  flex: none;
}

.info-list {
  display: grid;
  gap: 10px;
  padding-left: 18px;
  color: var(--text-muted);
  font-size: 14px;
  line-height: 1.6;
}

@media (max-width: 960px) {
  .hero-card,
  .featured-card {
    grid-template-columns: 1fr;
  }

  .support-grid {
    grid-template-columns: 1fr;
  }

  .content-layout {
    grid-template-columns: 1fr;
  }

  .ai-panel {
    grid-column: auto;
  }

  .hero-actions {
    justify-self: stretch;
  }

  .hero-title {
    max-width: none;
    font-size: 28px;
  }

  .hero-metrics,
  .hero-actions {
    grid-template-columns: 1fr;
  }
}

@media (max-width: 720px) {
  .hero-card,
  .tabs-card,
  .category-card,
  .feed-card,
  .featured-card,
  .ai-card {
    padding: 14px;
  }

  .tab-row,
  .product-grid,
  .hero-metrics,
  .hero-actions {
    grid-template-columns: 1fr;
  }

  .hero-buttons {
    flex-direction: column;
  }

  .hero-buttons > * {
    width: 100%;
  }

  .category-head,
  .feed-head {
    align-items: flex-start;
    flex-direction: column;
  }

  .featured-media {
    min-height: 240px;
  }
}
</style>
