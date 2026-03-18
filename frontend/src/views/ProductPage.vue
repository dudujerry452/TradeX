<script setup>
import { onMounted, reactive, watch } from 'vue'
import { useRoute } from 'vue-router'
import { getProductDetailApiUrl } from '../config/api'

const route = useRoute()

const state = reactive({
  loading: false,
  error: '',
  product: null,
})

const hideBrokenImage = (event) => {
  event.target.style.display = 'none'
}

const fetchProductDetail = async (productId) => {
  if (!productId) {
    state.product = null
    state.error = '请先从商品广场选择一个商品'
    return
  }

  state.loading = true
  state.error = ''

  try {
    const response = await fetch(getProductDetailApiUrl(productId))
    if (!response.ok) {
      let message = `加载商品详情失败: ${response.status}`
      try {
        const err = await response.json()
        if (err?.detail) message = err.detail
        if (err?.error) message = err.error
      } catch {
        // Keep fallback message when response body is not JSON.
      }
      throw new Error(message)
    }

    state.product = await response.json()
  } catch (error) {
    state.error = error instanceof Error ? error.message : '加载商品详情失败'
  } finally {
    state.loading = false
  }
}

watch(
  () => route.params.productId,
  (productId) => {
    fetchProductDetail(productId)
  },
)

onMounted(() => {
  fetchProductDetail(route.params.productId)
})
</script>

<template>
  <div class="product-page">
    <header class="topbar">
      <div class="site-name">tradeX</div>
      <nav class="nav-links">
        <RouterLink to="/home">Home</RouterLink>
        <RouterLink to="/login">Login</RouterLink>
      </nav>
    </header>

    <section v-if="state.loading" class="status-card">
      正在加载商品详情...
    </section>

    <section v-else-if="state.error" class="status-card status-error">
      {{ state.error }}
    </section>

    <section v-else-if="state.product" class="hero-section">
      <div class="hero-image">
        <img
          v-if="state.product.image_url"
          :src="state.product.image_url"
          :alt="state.product.product_name"
          class="hero-image-tag"
          loading="lazy"
          @error="hideBrokenImage"
        />
      </div>

      <article class="hero-info">
        <h1>{{ state.product.product_name }}</h1>
        <p class="subtitle">{{ state.product.category }}</p>
        <p class="price">¥{{ state.product.price }}</p>
        <p class="description">{{ state.product.description || '暂无商品描述' }}</p>

        <div class="meta-list">
          <p><strong>库存:</strong> {{ state.product.stock }}</p>
          <p><strong>发布者ID:</strong> {{ state.product.publisher_id }}</p>
          <p><strong>商品ID:</strong> {{ state.product.product_id }}</p>
          <p><strong>审核状态:</strong> {{ state.product.product_status }}</p>
        </div>

        <RouterLink to="/home" class="back-btn">返回商品广场</RouterLink>
      </article>
    </section>
  </div>
</template>

<style scoped>
.product-page {
  min-height: 100vh;
  background: linear-gradient(180deg, #f2f1f8 0%, #f7f6fc 100%);
  color: #111;
  font-family: 'Microsoft YaHei', 'PingFang SC', sans-serif;
  padding: 18px 30px 36px;
}

.topbar {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 32px;
}

.site-name {
  font-size: 14px;
  font-weight: 600;
}

.nav-links {
  display: flex;
  align-items: center;
  gap: 20px;
}

.nav-links a {
  text-decoration: none;
  color: #111;
  font-size: 14px;
  font-weight: 600;
}

.hero-section {
  display: grid;
  grid-template-columns: minmax(360px, 1fr) minmax(300px, 0.9fr);
  gap: 36px;
  align-items: start;
}

.hero-image {
  width: 100%;
  min-height: 520px;
  border-radius: 10px;
  overflow: hidden;
  background: linear-gradient(130deg, #c5d4df 0%, #a8b7c5 40%, #d5dde5 100%);
}

.hero-image-tag {
  width: 100%;
  height: 100%;
  min-height: 520px;
  object-fit: cover;
  display: block;
}

.hero-info h1 {
  margin: 0;
  font-size: 44px;
  line-height: 1.1;
}

.subtitle {
  margin: 10px 0 12px;
  color: #6a6a6a;
  font-size: 24px;
}

.price {
  margin: 0 0 20px;
  font-size: 34px;
  font-weight: 700;
}

.description {
  margin: 0 0 18px;
  font-size: 15px;
  color: #555;
  line-height: 1.6;
}

.meta-list {
  display: grid;
  gap: 8px;
  margin-bottom: 20px;
}

.meta-list p {
  margin: 0;
  font-size: 14px;
  color: #333;
}

.back-btn {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  text-decoration: none;
  border-radius: 8px;
  border: 0;
  background: #000;
  color: #fff;
  padding: 12px 18px;
  font-size: 14px;
  font-weight: 600;
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

@media (max-width: 980px) {
  .product-page {
    padding: 14px 16px 24px;
  }

  .topbar {
    margin-bottom: 20px;
  }

  .hero-section {
    grid-template-columns: 1fr;
    gap: 20px;
  }

  .hero-image,
  .hero-image-tag {
    min-height: 280px;
  }

  .hero-info h1 {
    font-size: 32px;
  }

  .subtitle {
    font-size: 20px;
  }

  .price {
    font-size: 24px;
    margin-bottom: 16px;
  }
}
</style>
