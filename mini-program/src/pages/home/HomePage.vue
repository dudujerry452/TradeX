<script setup>
import { computed, onMounted, reactive } from 'vue'
import { PRODUCTS_API_URL } from '../../config/api'

const state = reactive({
  products: [],
  loading: false,
  error: '',
})

const featuredProduct = computed(() => state.products[0] || null)

const fetchProducts = () => {
  state.loading = true
  state.error = ''

  uni.request({
    url: PRODUCTS_API_URL,
    method: 'GET',
    success: (res) => {
      if (res.statusCode === 200) {
        state.products = Array.isArray(res.data) ? res.data : []
      } else {
        state.error = res.data?.detail || `加载商品失败: ${res.statusCode}`
      }
    },
    fail: () => {
      state.error = '加载商品失败，请检查网络'
    },
    complete: () => {
      state.loading = false
    },
  })
}

const goToProduct = (productId) => {
  uni.navigateTo({ url: `/pages/product/ProductPage?productId=${productId}` })
}

onMounted(() => {
  fetchProducts()
})
</script>

<template>
  <view class="home-page">
    <view class="hero">
      <view class="topbar">
        <text class="site-name">tradeX</text>
        <view class="nav-links">
          <text class="nav-link" @tap="() => uni.redirectTo({ url: '/pages/login/UserLogin' })">Login</text>
          <text class="ghost-btn" @tap="fetchProducts">刷新商品</text>
        </view>
      </view>
      <view class="hero-content">
        <text class="hero-title">tradeX 商品广场</text>
      </view>
    </view>

    <view class="content">
      <view v-if="featuredProduct" class="feature">
        <view class="media-block">
          <image
            v-if="featuredProduct.image_url"
            :src="featuredProduct.image_url"
            mode="aspectFill"
            class="media-image"
          />
        </view>
        <view class="text-block">
          <text class="feature-name">{{ featuredProduct.product_name }}</text>
          <text class="feature-meta">{{ featuredProduct.category }} | 库存 {{ featuredProduct.stock }}</text>
          <view class="actions">
            <text class="price-tag">¥{{ featuredProduct.price }}</text>
            <text class="primary-btn" @tap="goToProduct(featuredProduct.product_id)">查看详情</text>
          </view>
        </view>
      </view>

      <view v-if="state.loading" class="status-card">
        <text>正在加载商品数据...</text>
      </view>

      <view v-else-if="state.error" class="status-card status-error">
        <text>{{ state.error }}</text>
      </view>

      <view v-else-if="!state.products.length" class="status-card">
        <text>当前暂无商品数据</text>
      </view>

      <view v-else class="products-section">
        <text class="section-title">最新商品</text>
        <view class="product-grid">
          <view
            v-for="item in state.products"
            :key="item.product_id"
            class="product-card"
            @tap="goToProduct(item.product_id)"
          >
            <view class="product-media">
              <image
                v-if="item.image_url"
                :src="item.image_url"
                mode="aspectFill"
                class="media-image"
              />
            </view>
            <text class="product-name">{{ item.product_name }}</text>
            <text class="product-meta">{{ item.category }} | 库存 {{ item.stock }}</text>
            <view class="card-footer">
              <text class="price-tag">¥{{ item.price }}</text>
              <text class="secondary-btn">查看详情</text>
            </view>
          </view>
        </view>
      </view>
    </view>
  </view>
</template>

<style scoped>
.home-page {
  min-height: 100vh;
  background: linear-gradient(180deg, #f2f1f8 0%, #f7f6fc 100%);
  font-family: 'Microsoft YaHei', 'PingFang SC', sans-serif;
}

.hero {
  min-height: 200px;
  padding: 40px 24px;
  display: flex;
  flex-direction: column;
  background: linear-gradient(rgba(0,0,0,0.35), rgba(0,0,0,0.35)),
              linear-gradient(115deg, #c9cbcb 0%, #9da2a2 35%, #cbcccc 100%);
}

.topbar {
  display: flex;
  align-items: center;
  justify-content: space-between;
}

.site-name {
  color: rgba(255,255,255,0.86);
  font-size: 14px;
}

.nav-links {
  display: flex;
  align-items: center;
  gap: 20px;
}

.nav-link {
  color: rgba(255,255,255,0.9);
  font-size: 14px;
}

.ghost-btn {
  color: #fff;
  border: 1px solid rgba(255,255,255,0.7);
  border-radius: 8px;
  padding: 6px 14px;
  font-size: 13px;
}

.hero-content {
  flex: 1;
  display: flex;
  align-items: center;
  justify-content: center;
  margin-top: 20px;
}

.hero-title {
  font-size: 32px;
  font-weight: 800;
  color: #fff;
}

.content {
  padding: 24px 16px 48px;
  display: flex;
  flex-direction: column;
  gap: 24px;
}

.feature {
  display: flex;
  flex-direction: column;
  gap: 16px;
}

.media-block {
  width: 100%;
  height: 200px;
  border-radius: 10px;
  overflow: hidden;
  background: linear-gradient(130deg, #d7d7d7 20%, #e5e5e5 45%, #cdcdcd 100%);
}

.media-image {
  width: 100%;
  height: 100%;
}

.text-block {
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.feature-name {
  font-size: 24px;
  font-weight: 700;
  color: #111;
}

.feature-meta {
  font-size: 14px;
  color: #666;
}

.actions {
  display: flex;
  align-items: center;
  gap: 12px;
  margin-top: 4px;
}

.price-tag {
  display: inline-flex;
  padding: 6px 12px;
  background: #111;
  color: #fff;
  border-radius: 999px;
  font-weight: 700;
  font-size: 14px;
}

.primary-btn {
  background: #000;
  color: #fff;
  border-radius: 8px;
  padding: 10px 16px;
  font-size: 14px;
  font-weight: 600;
}

.status-card {
  background: #fff;
  border: 1px solid #ddd;
  border-radius: 10px;
  padding: 18px;
}

.status-card text {
  font-size: 15px;
  font-weight: 600;
}

.status-error {
  border-color: #f2b8b5;
  background: #fff7f7;
}

.status-error text {
  color: #b42318;
}

.products-section {
  display: flex;
  flex-direction: column;
  gap: 14px;
}

.section-title {
  font-size: 22px;
  font-weight: 700;
  color: #111;
}

.product-grid {
  display: flex;
  flex-direction: column;
  gap: 12px;
}

.product-card {
  background: #fff;
  border: 1px solid #ddd;
  border-radius: 10px;
  padding: 12px;
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.product-media {
  height: 140px;
  border-radius: 8px;
  overflow: hidden;
  background: linear-gradient(130deg, #d6d6d6 0%, #ececec 50%, #d2d2d2 100%);
}

.product-name {
  font-size: 16px;
  font-weight: 700;
  color: #111;
}

.product-meta {
  font-size: 13px;
  color: #666;
}

.card-footer {
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.secondary-btn {
  background: #d8d8d8;
  color: #111;
  border-radius: 8px;
  padding: 8px 12px;
  font-size: 13px;
  font-weight: 600;
}
</style>
