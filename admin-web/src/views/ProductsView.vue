<template>
  <section class="page-stack">
    <section class="panel">
      <div class="panel-head panel-head--split">
        <div>
          <p class="eyebrow">商品审核</p>
          <h3>审核通过、驳回或下架</h3>
        </div>
        <div class="toolbar-actions">
          <button class="ghost-btn" type="button" @click="resetFilters">重置</button>
          <button class="primary-btn primary-btn--sm" type="button" @click="handleSearch">搜索</button>
        </div>
      </div>

      <div class="filters-grid">
        <input v-model.trim="keyword" class="input" type="text" placeholder="搜索商品名 / 描述 / 发布者" @keyup.enter="handleSearch" />
        <select v-model="statusFilter" class="input">
          <option value="">全部状态</option>
          <option value="PENDING">待审核</option>
          <option value="APPROVED">审核通过</option>
          <option value="OFF_SHELF">已下架</option>
          <option value="REJECTED">审核驳回</option>
        </select>
      </div>
    </section>

    <section class="panel">
      <div class="table-toolbar">
        <span class="muted">共 {{ total }} 条数据</span>
        <span class="muted">第 {{ page }} / {{ totalPages }} 页</span>
      </div>

      <div class="table-wrap">
        <table class="data-table data-table--products">
          <thead>
            <tr>
              <th>商品</th>
              <th>分类</th>
              <th>状态</th>
              <th>库存 / 价格</th>
              <th>发布者</th>
              <th>操作</th>
            </tr>
          </thead>
          <tbody>
            <tr v-if="loading">
              <td colspan="6" class="table-empty">加载中...</td>
            </tr>
            <tr v-else-if="!items.length">
              <td colspan="6" class="table-empty">暂无商品数据</td>
            </tr>
            <tr v-for="item in items" :key="item.product_id">
              <td>
                <div class="table-product-cell">
                  <img :src="item.image_url" :alt="item.product_name" />
                  <div>
                    <strong>{{ item.product_name }}</strong>
                    <small>{{ item.product_id }}</small>
                  </div>
                </div>
              </td>
              <td>
                <div class="table-main-cell">
                  <strong>{{ item.category_name || item.category || '—' }}</strong>
                  <small>{{ item.category || '—' }}</small>
                </div>
              </td>
              <td>
                <span :class="['status-pill', `status-pill--${getProductStatusMeta(item.product_status).tone}`]">
                  {{ getProductStatusMeta(item.product_status).label }}
                </span>
              </td>
              <td>
                <div class="table-main-cell">
                  <strong>¥{{ formatMoney(item.price) }}</strong>
                  <small>库存 {{ item.stock }}</small>
                </div>
              </td>
              <td>
                <div class="table-main-cell">
                  <strong>{{ item.publisher_name || item.publisher_id }}</strong>
                  <small>{{ formatDateTime(item.publish_time) }}</small>
                </div>
              </td>
              <td>
                <div class="table-actions">
                  <button class="action-btn action-btn--success" type="button" @click="changeStatus(item, 'APPROVED')">
                    通过
                  </button>
                  <button class="action-btn action-btn--danger" type="button" @click="changeStatus(item, 'REJECTED')">
                    驳回
                  </button>
                  <button class="action-btn action-btn--muted" type="button" @click="changeStatus(item, 'OFF_SHELF')">
                    下架
                  </button>
                </div>
              </td>
            </tr>
          </tbody>
        </table>
      </div>

      <div class="pagination">
        <button class="ghost-btn" type="button" :disabled="page <= 1 || loading" @click="prevPage">上一页</button>
        <button class="ghost-btn" type="button" :disabled="page >= totalPages || loading" @click="nextPage">下一页</button>
      </div>
    </section>
  </section>
</template>

<script setup>
import { computed, onMounted, ref } from 'vue'

import { getAdminProducts, updateAdminProductStatus } from '../services/api'
import { formatDateTime, formatMoney, getProductStatusMeta } from '../utils/display'

const keyword = ref('')
const statusFilter = ref('')
const loading = ref(false)
const items = ref([])
const total = ref(0)
const page = ref(1)
const pageSize = 10

const totalPages = computed(() => Math.max(1, Math.ceil(total.value / pageSize)))

const loadProducts = async () => {
  loading.value = true
  const result = await getAdminProducts({
    q: keyword.value.trim(),
    status: statusFilter.value,
    limit: pageSize,
    offset: (page.value - 1) * pageSize,
  })

  loading.value = false

  if (result.success) {
    items.value = result.data?.items || []
    total.value = result.data?.total || 0
  }
}

const handleSearch = async () => {
  page.value = 1
  await loadProducts()
}

const resetFilters = async () => {
  keyword.value = ''
  statusFilter.value = ''
  page.value = 1
  await loadProducts()
}

const prevPage = async () => {
  if (page.value <= 1) return
  page.value -= 1
  await loadProducts()
}

const nextPage = async () => {
  if (page.value >= totalPages.value) return
  page.value += 1
  await loadProducts()
}

const changeStatus = async (item, productStatus) => {
  if (!window.confirm(`确认将 ${item.product_name} 更新为 ${productStatus} 吗？`)) {
    return
  }

  const result = await updateAdminProductStatus(item.product_id, { product_status: productStatus })
  if (result.success) {
    await loadProducts()
  } else {
    window.alert(result.message || '更新失败')
  }
}

onMounted(loadProducts)
</script>
