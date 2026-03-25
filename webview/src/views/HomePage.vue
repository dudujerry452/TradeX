<script setup>
import { computed, onMounted, reactive } from 'vue'
import { PRODUCTS_API_URL } from '../config/api'
import { floatingIcons } from '../config/loginFloatingIcons'
import RagChatPanel from '../components/RagChatPanel.vue'

const state = reactive({
  products: [],
  loading: false,
  error: '',
})

const featuredProduct = computed(() => state.products[0] || null)

const hideBrokenImage = (event) => {
  event.target.style.display = 'none'
}

const fetchProducts = async () => {
  state.loading = true
  state.error = ''

  try {
    const response = await fetch(PRODUCTS_API_URL)
    if (!response.ok) {
      let msg = `加载商品失败: ${response.status}`
      try {
        const err = await response.json()
        if (err?.detail) msg = err.detail
        if (err?.error) msg = err.error
      } catch {
        // Keep fallback message when response body is not JSON.
      }
      throw new Error(msg)
    }

    const data = await response.json()
    state.products = Array.isArray(data) ? data : []
  } catch (error) {
    state.error = error instanceof Error ? error.message : '加载商品失败'
  } finally {
    state.loading = false
  }
}

onMounted(() => {
  fetchProducts()
})
</script>

<template>
  <div class="home-page">
    <div class="bg-dots" aria-hidden="true"></div>
    <div
      v-for="(icon, index) in floatingIcons"
      :key="`${icon.top}-${icon.left}-${index}`"
      class="floating-icon"
      :style="{
        top: icon.top,
        left: icon.left,
        width: icon.size,
        '--float-duration': icon.duration,
        '--float-delay': icon.delay,
      }"
      aria-hidden="true"
    >
      <img :src="icon.src" alt="" />
    </div>

    <section class="hero">
      <header class="topbar">
        <div class="site-name">tradeX</div>
        <nav class="nav-links">
          <RouterLink to="/home">Home</RouterLink>
          <RouterLink to="/product">Products</RouterLink>
          <RouterLink to="/login">Login</RouterLink>
          <button type="button" class="ghost-btn" @click="fetchProducts">刷新商品</button>
        </nav>
      </header>

      <div class="hero-content">
        <h1>tradeX 商品广场</h1>
      </div>
    </section>

    <section class="content">
      <article class="feature feature-left" v-if="featuredProduct">
        <div class="text-block featured-text">
          <h2>{{ featuredProduct.product_name }}</h2>
          <p>{{ featuredProduct.category }} | 库存 {{ featuredProduct.stock }}</p>
          <div class="actions">
            <span class="price-tag">¥{{ featuredProduct.price }}</span>
            <RouterLink
              class="primary-btn detail-btn"
              :to="`/product/${featuredProduct.product_id}`"
            >
              查看详情
            </RouterLink>
          </div>
        </div>
        <div class="media-block">
          <img
            v-if="featuredProduct.image_url"
            :src="featuredProduct.image_url"
            :alt="featuredProduct.product_name"
            class="media-image"
            loading="lazy"
            @error="hideBrokenImage"
          />
        </div>
      </article>

      <article v-if="state.loading" class="status-card">
        正在加载商品数据...
      </article>

      <article v-else-if="state.error" class="status-card status-error">
        {{ state.error }}
      </article>

      <article v-else-if="!state.products.length" class="status-card">
        当前暂无商品数据
      </article>

      <RagChatPanel />

      <section v-if="!state.loading && !state.error && state.products.length" class="products-section">
        <h2 class="section-title">最新商品</h2>
        <div class="product-grid">
          <article v-for="item in state.products" :key="item.product_id" class="product-card">
            <div class="product-media">
              <img
                v-if="item.image_url"
                :src="item.image_url"
                :alt="item.product_name"
                class="media-image"
                loading="lazy"
                @error="hideBrokenImage"
              />
            </div>
            <h3>{{ item.product_name }}</h3>
            <p class="product-meta">{{ item.category }} | 库存 {{ item.stock }}</p>
            <div class="card-footer">
              <span class="price-tag">¥{{ item.price }}</span>
              <RouterLink class="secondary-btn detail-link" :to="`/product/${item.product_id}`">
                查看详情
              </RouterLink>
            </div>
          </article>
        </div>
      </section>
    </section>
  </div>
</template>

<style scoped>
.home-page {
  min-height: 100vh;
  background: linear-gradient(180deg, #f2f1f8 0%, #f7f6fc 100%);
  color: #111;
  font-family: 'Microsoft YaHei', 'PingFang SC', sans-serif;
  position: relative;
  overflow: hidden;
  isolation: isolate;
}

.bg-dots {
  position: absolute;
  inset: 0;
  z-index: -2;
  opacity: 0.4;
  background-image: radial-gradient(circle, rgba(153, 158, 184, 0.42) 1px, transparent 1px);
  background-size: 13px 13px;
}

.floating-icon {
  position: absolute;
  z-index: -1;
  opacity: 0.85;
  will-change: transform;
  animation: floatDrift var(--float-duration) ease-in-out infinite;
  animation-delay: var(--float-delay);
}

.floating-icon:nth-of-type(even) {
  animation-direction: reverse;
}

.floating-icon img {
  width: 100%;
  display: block;
  filter: drop-shadow(0 6px 11px rgba(61, 70, 102, 0.1));
  animation: iconSwing calc(var(--float-duration) * 0.7) ease-in-out infinite alternate;
}

.hero {
  min-height: 420px;
  padding: 40px 48px;
  position: relative;
  display: flex;
  flex-direction: column;
  border-bottom: 1px solid #dedede;
  background:
    linear-gradient(rgba(0, 0, 0, 0.35), rgba(0, 0, 0, 0.35)),
    linear-gradient(115deg, #c9cbcb 0%, #9da2a2 35%, #cbcccc 100%);
}

.topbar {
  display: flex;
  align-items: center;
  justify-content: space-between;
}

.site-name {
  color: rgba(255, 255, 255, 0.86);
  font-size: 14px;
  letter-spacing: 0.01em;
}

.nav-links {
  display: flex;
  align-items: center;
  gap: 28px;
}

.nav-links a {
  color: rgba(255, 255, 255, 0.9);
  text-decoration: none;
  font-size: 14px;
}

.nav-links :deep(a.router-link-active) {
  text-decoration: underline;
}

.hero-content {
  margin: auto;
  text-align: center;
  color: #fff;
}

.hero-content h1 {
  margin: 0;
  font-size: 64px;
  line-height: 1.1;
}

.hero-content p {
  margin: 16px 0 28px;
  font-size: 32px;
  opacity: 0.95;
}

.content {
  padding: 54px 48px 72px;
  display: grid;
  gap: 42px;
  max-width: 1240px;
  margin: 0 auto;
}

.feature {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 26px;
  align-items: center;
}

.feature-right .text-block {
  order: 2;
}

.feature-right .media-block {
  order: 1;
}

.text-block h2 {
  margin: 0;
  font-size: 54px;
  line-height: 1.1;
}

.text-block p {
  margin: 18px 0 26px;
  max-width: 440px;
  font-size: 34px;
  color: #676767;
  line-height: 1.35;
}

.media-block {
  width: 100%;
  min-height: 320px;
  border-radius: 6px;
  overflow: hidden;
  background:
    linear-gradient(120deg, #d7d7d7 20%, #e5e5e5 45%, #cdcdcd 100%);
}

.media-image {
  width: 100%;
  height: 100%;
  min-height: inherit;
  object-fit: cover;
  display: block;
}

.featured-text h2 {
  margin-bottom: 10px;
}

.price-tag {
  display: inline-flex;
  align-items: center;
  padding: 8px 14px;
  background: #111;
  color: #fff;
  border-radius: 999px;
  font-weight: 700;
}

.status-card {
  background: #fff;
  border: 1px solid #ddd;
  border-radius: 10px;
  padding: 18px;
  font-size: 16px;
  font-weight: 600;
}

.status-error {
  color: #b42318;
  border-color: #f2b8b5;
  background: #fff7f7;
}

.products-section {
  display: grid;
  gap: 18px;
}

.section-title {
  margin: 0;
  font-size: 34px;
  line-height: 1.1;
}

.product-grid {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 16px;
}

.product-card {
  background: #fff;
  border: 1px solid #ddd;
  border-radius: 10px;
  padding: 12px;
  display: grid;
  gap: 10px;
}

.product-media {
  min-height: 140px;
  border-radius: 8px;
  overflow: hidden;
  background: linear-gradient(130deg, #d6d6d6 0%, #ececec 50%, #d2d2d2 100%);
}

.product-card h3 {
  margin: 0;
  font-size: 22px;
  line-height: 1.2;
}

.product-meta {
  margin: 0;
  color: #666;
  font-size: 14px;
}

.card-footer {
  display: flex;
  justify-content: space-between;
  gap: 12px;
  align-items: center;
}

.detail-btn {
  text-decoration: none;
}

.detail-link {
  text-decoration: none;
  padding: 8px 12px;
  font-size: 14px;
}

.actions {
  display: flex;
  align-items: center;
  gap: 14px;
}

.primary-btn,
.secondary-btn,
.ghost-btn {
  border-radius: 8px;
  border: 0;
  font-size: 16px;
  line-height: 1;
  padding: 12px 20px;
  font-weight: 600;
  cursor: pointer;
}

@keyframes floatDrift {
  0% {
    transform: translate3d(0, 0, 0);
  }
  25% {
    transform: translate3d(10px, -14px, 0);
  }
  50% {
    transform: translate3d(-12px, -24px, 0);
  }
  75% {
    transform: translate3d(12px, -10px, 0);
  }
  100% {
    transform: translate3d(0, 0, 0);
  }
}

@keyframes iconSwing {
  0% {
    transform: rotate(-4deg) scale(1);
  }
  100% {
    transform: rotate(4deg) scale(1.05);
  }
}

.primary-btn {
  color: #fff;
  background: #000;
}

.secondary-btn {
  color: #111;
  background: #d8d8d8;
}

.ghost-btn {
  color: #fff;
  background: transparent;
  border: 1px solid rgba(255, 255, 255, 0.7);
  padding: 10px 18px;
}

@media (max-width: 900px) {
  .hero {
    min-height: 360px;
    padding: 26px 20px;
  }

  .hero-content h1 {
    font-size: 42px;
  }

  .hero-content p {
    font-size: 20px;
    margin: 12px 0 20px;
  }

  .nav-links {
    gap: 14px;
  }

  .content {
    padding: 28px 20px 42px;
    gap: 24px;
  }

  .feature {
    grid-template-columns: 1fr;
  }

  .feature-right .text-block,
  .feature-right .media-block {
    order: initial;
  }

  .text-block h2 {
    font-size: 34px;
  }

  .text-block p {
    font-size: 20px;
    margin: 12px 0 18px;
  }

  .media-block {
    min-height: 220px;
  }

  .actions {
    flex-wrap: wrap;
  }

  .product-grid {
    grid-template-columns: 1fr;
  }

  .section-title {
    font-size: 28px;
  }
}
</style>
