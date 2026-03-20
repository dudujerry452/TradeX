<script setup>
import { onMounted, reactive } from 'vue'
import { getProductDetailApiUrl } from '../../config/api'

const props = defineProps({
  productId: { type: String, default: '' },
})

const state = reactive({
  loading: false,
  error: '',
  product: null,
})

const fetchProductDetail = (productId) => {
  if (!productId) {
    state.error = '请先从商品广场选择一个商品'
    return
  }

  state.loading = true
  state.error = ''

  uni.request({
    url: getProductDetailApiUrl(productId),
    method: 'GET',
    success: (res) => {
      if (res.statusCode === 200) {
        state.product = res.data
      } else {
        state.error = res.data?.detail || `加载商品详情失败: ${res.statusCode}`
      }
    },
    fail: () => {
      state.error = '加载商品详情失败，请检查网络'
    },
    complete: () => {
      state.loading = false
    },
  })
}

onMounted(() => {
  fetchProductDetail(props.productId)
})
</script>

<template>
  <view class="product-page">
    <view class="topbar">
      <text class="site-name">tradeX</text>
      <view class="nav-links">
        <text class="nav-link" @tap="() => uni.navigateTo({ url: '/pages/home/HomePage' })">Home</text>
        <text class="nav-link" @tap="() => uni.redirectTo({ url: '/pages/login/UserLogin' })">Login</text>
      </view>
    </view>

    <view v-if="state.loading" class="status-card">
      <text>正在加载商品详情...</text>
    </view>

    <view v-else-if="state.error" class="status-card status-error">
      <text>{{ state.error }}</text>
    </view>

    <view v-else-if="state.product" class="detail">
      <view class="hero-image">
        <image
          v-if="state.product.image_url"
          :src="state.product.image_url"
          mode="aspectFill"
          class="hero-image-tag"
        />
      </view>

      <view class="info">
        <text class="product-name">{{ state.product.product_name }}</text>
        <text class="subtitle">{{ state.product.category }}</text>
        <text class="price">¥{{ state.product.price }}</text>
        <text class="description">{{ state.product.description || '暂无商品描述' }}</text>

        <view class="meta-list">
          <text class="meta-item"><text class="meta-key">库存: </text>{{ state.product.stock }}</text>
          <text class="meta-item"><text class="meta-key">发布者ID: </text>{{ state.product.publisher_id }}</text>
          <text class="meta-item"><text class="meta-key">商品ID: </text>{{ state.product.product_id }}</text>
          <text class="meta-item"><text class="meta-key">审核状态: </text>{{ state.product.product_status }}</text>
        </view>

        <text class="back-btn" @tap="() => uni.navigateBack()">返回商品广场</text>
      </view>
    </view>
  </view>
</template>

<style scoped>
.product-page {
  min-height: 100vh;
  background: linear-gradient(180deg, #f2f1f8 0%, #f7f6fc 100%);
  padding: 18px 16px 36px;
}

.topbar {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 20px;
}

.site-name {
  font-size: 14px;
  font-weight: 600;
  color: #111;
}

.nav-links {
  display: flex;
  gap: 16px;
}

.nav-link {
  font-size: 14px;
  font-weight: 600;
  color: #111;
}

.detail {
  display: flex;
  flex-direction: column;
  gap: 20px;
}

.hero-image {
  width: 100%;
  height: 280px;
  border-radius: 10px;
  overflow: hidden;
  background: linear-gradient(130deg, #c5d4df 0%, #a8b7c5 40%, #d5dde5 100%);
}

.hero-image-tag {
  width: 100%;
  height: 100%;
}

.info {
  display: flex;
  flex-direction: column;
  gap: 10px;
}

.product-name {
  font-size: 28px;
  font-weight: 800;
  color: #111;
  line-height: 1.2;
}

.subtitle {
  font-size: 16px;
  color: #6a6a6a;
}

.price {
  font-size: 24px;
  font-weight: 700;
  color: #111;
}

.description {
  font-size: 14px;
  color: #555;
  line-height: 1.6;
}

.meta-list {
  display: flex;
  flex-direction: column;
  gap: 6px;
  background: #fff;
  border-radius: 10px;
  padding: 14px;
  border: 1px solid #eee;
}

.meta-item {
  font-size: 13px;
  color: #333;
}

.meta-key {
  font-weight: 700;
}

.back-btn {
  display: flex;
  align-items: center;
  justify-content: center;
  background: #000;
  color: #fff;
  border-radius: 10px;
  padding: 14px;
  font-size: 15px;
  font-weight: 600;
  margin-top: 6px;
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
</style>
