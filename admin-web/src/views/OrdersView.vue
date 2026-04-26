<template>
  <section class="page-stack">
    <section class="panel">
      <div class="panel-head panel-head--split">
        <div>
          <p class="eyebrow">订单处理</p>
          <h3>推进付款、发货、完成与取消</h3>
        </div>
        <div class="toolbar-actions">
          <button class="ghost-btn" type="button" @click="resetFilters">重置</button>
          <button class="primary-btn primary-btn--sm" type="button" @click="handleSearch">搜索</button>
        </div>
      </div>

      <div class="filters-grid">
        <input v-model.trim="keyword" class="input" type="text" placeholder="搜索订单号 / 买家 / 卖家 / 商品" @keyup.enter="handleSearch" />
        <select v-model="statusFilter" class="input">
          <option value="">全部状态</option>
          <option value="PENDING_PAY">待付款</option>
          <option value="PENDING_SHIP">待发货</option>
          <option value="SHIPPED">已发货</option>
          <option value="COMPLETED">已完成</option>
          <option value="CANCELED">已取消</option>
        </select>
      </div>
    </section>

    <section class="panel">
      <div class="table-toolbar">
        <span class="muted">共 {{ total }} 条数据</span>
        <span class="muted">第 {{ page }} / {{ totalPages }} 页</span>
      </div>

      <div class="table-wrap">
        <table class="data-table">
          <thead>
            <tr>
              <th>订单</th>
              <th>买家 / 卖家</th>
              <th>状态</th>
              <th>金额</th>
              <th>时间</th>
              <th>操作</th>
            </tr>
          </thead>
          <tbody>
            <tr v-if="loading">
              <td colspan="6" class="table-empty">加载中...</td>
            </tr>
            <tr v-else-if="!items.length">
              <td colspan="6" class="table-empty">暂无订单数据</td>
            </tr>
            <tr
              v-for="item in items"
              :key="item.order_id"
              :class="{ 'row-active': selectedOrder?.order_id === item.order_id }"
              @click="selectOrder(item)"
            >
              <td>
                <div class="table-main-cell">
                  <strong>{{ item.order_id }}</strong>
                  <small>{{ item.products?.length || 0 }} 件商品</small>
                </div>
              </td>
              <td>
                <div class="table-main-cell">
                  <strong>{{ item.buyer_name }}</strong>
                  <small>卖家：{{ item.seller_name }}</small>
                </div>
              </td>
              <td>
                <span :class="['status-pill', `status-pill--${getOrderStatusMeta(item.order_status).tone}`]">
                  {{ getOrderStatusMeta(item.order_status).label }}
                </span>
              </td>
              <td>
                <strong>¥{{ formatMoney(item.total_amount) }}</strong>
              </td>
              <td>
                <div class="table-main-cell">
                  <span>{{ formatDateTime(item.order_time) }}</span>
                  <small>{{ item.logistics_company || '—' }}</small>
                </div>
              </td>
              <td @click.stop>
                <div class="table-actions">
                  <button v-if="item.order_status === 'PENDING_PAY'" class="action-btn action-btn--accent" type="button" @click="handleChangeStatus(item, 'PENDING_SHIP')">
                    确认付款
                  </button>
                  <button v-if="item.order_status === 'PENDING_SHIP'" class="action-btn action-btn--success" type="button" @click="handleChangeStatus(item, 'SHIPPED')">
                    发货
                  </button>
                  <button v-if="item.order_status === 'SHIPPED'" class="action-btn action-btn--success" type="button" @click="handleChangeStatus(item, 'COMPLETED')">
                    完成
                  </button>
                  <button v-if="item.order_status !== 'COMPLETED' && item.order_status !== 'CANCELED'" class="action-btn action-btn--danger" type="button" @click="handleChangeStatus(item, 'CANCELED')">
                    取消
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

    <section v-if="selectedOrder" class="panel order-detail-panel">
      <div class="panel-head panel-head--split">
        <div>
          <p class="eyebrow">订单详情</p>
          <h3>{{ selectedOrder.order_id }}</h3>
        </div>
        <span :class="['status-pill', `status-pill--${getOrderStatusMeta(selectedOrder.order_status).tone}`]">
          {{ getOrderStatusMeta(selectedOrder.order_status).label }}
        </span>
      </div>

      <div class="detail-grid">
        <div class="detail-block">
          <strong>买家 / 卖家</strong>
          <span>{{ selectedOrder.buyer_name }} / {{ selectedOrder.seller_name }}</span>
        </div>
        <div class="detail-block">
          <strong>物流信息</strong>
          <span>{{ selectedOrder.logistics_company || '—' }} {{ selectedOrder.logistics_number || '' }}</span>
        </div>
        <div class="detail-block">
          <strong>收货地址</strong>
          <span>{{ selectedOrder.address_snapshot }}</span>
        </div>
        <div class="detail-block">
          <strong>联系电话</strong>
          <span>{{ selectedOrder.phone_snapshot }}</span>
        </div>
      </div>

      <div class="subpanel">
        <div class="subpanel-head">
          <h4>商品明细</h4>
        </div>
        <div class="order-product-list">
          <article v-for="product in selectedOrder.products || []" :key="product.product_id" class="order-product-row">
            <img :src="product.image_url" :alt="product.product_name" />
            <div>
              <strong>{{ product.product_name }}</strong>
              <span>¥{{ formatMoney(product.price) }} × {{ product.quantity }}</span>
            </div>
            <b>¥{{ formatMoney(product.subtotal) }}</b>
          </article>
        </div>
      </div>

      <div class="subpanel">
        <div class="subpanel-head">
          <h4>订单日志</h4>
          <button class="ghost-btn ghost-btn--sm" type="button" @click="reloadOrderLogs">刷新</button>
        </div>
        <div v-if="logsLoading" class="table-empty">加载中...</div>
        <ol v-else class="timeline">
          <li v-for="log in orderLogs" :key="log.log_id">
            <strong>{{ log.action_display }}</strong>
            <span>{{ formatDateTime(log.created_at) }}</span>
            <p>{{ log.remark || '—' }}</p>
            <small>{{ log.operator_name || '系统' }}</small>
          </li>
          <li v-if="!orderLogs.length" class="table-empty">暂无日志</li>
        </ol>
      </div>
    </section>
  </section>
</template>

<script setup>
import { computed, onMounted, ref } from 'vue'

import { getAdminOrderLogs, getAdminOrders, updateAdminOrderStatus } from '../services/api'
import { formatDateTime, formatMoney, getOrderStatusMeta } from '../utils/display'

const keyword = ref('')
const statusFilter = ref('')
const loading = ref(false)
const logsLoading = ref(false)
const items = ref([])
const total = ref(0)
const page = ref(1)
const pageSize = 10
const selectedOrder = ref(null)
const orderLogs = ref([])

const totalPages = computed(() => Math.max(1, Math.ceil(total.value / pageSize)))

const loadOrders = async () => {
  loading.value = true
  const result = await getAdminOrders({
    q: keyword.value.trim(),
    status: statusFilter.value,
    limit: pageSize,
    offset: (page.value - 1) * pageSize,
  })

  loading.value = false

  if (result.success) {
    items.value = result.data?.items || []
    total.value = result.data?.total || 0
    if (selectedOrder.value) {
      const nextSelected = items.value.find((item) => item.order_id === selectedOrder.value.order_id)
      if (nextSelected) {
        selectedOrder.value = nextSelected
      }
    }
  }
}

const loadOrderLogs = async (orderId) => {
  if (!orderId) return

  logsLoading.value = true
  const result = await getAdminOrderLogs(orderId)
  logsLoading.value = false

  if (result.success) {
    orderLogs.value = result.data || []
  }
}

const selectOrder = async (item) => {
  selectedOrder.value = item
  await loadOrderLogs(item.order_id)
}

const handleSearch = async () => {
  page.value = 1
  selectedOrder.value = null
  orderLogs.value = []
  await loadOrders()
}

const resetFilters = async () => {
  keyword.value = ''
  statusFilter.value = ''
  page.value = 1
  selectedOrder.value = null
  orderLogs.value = []
  await loadOrders()
}

const prevPage = async () => {
  if (page.value <= 1) return
  page.value -= 1
  await loadOrders()
}

const nextPage = async () => {
  if (page.value >= totalPages.value) return
  page.value += 1
  await loadOrders()
}

const reloadOrderLogs = async () => {
  if (!selectedOrder.value) return
  await loadOrderLogs(selectedOrder.value.order_id)
}

const handleChangeStatus = async (item, nextStatus) => {
  let payload = { order_status: nextStatus }

  if (nextStatus === 'SHIPPED') {
    const logisticsCompany = window.prompt('请输入物流公司', item.logistics_company || '')
    if (logisticsCompany === null) return
    const logisticsNumber = window.prompt('请输入物流单号', item.logistics_number || '')
    if (logisticsNumber === null) return

    payload = {
      ...payload,
      logistics_company: logisticsCompany.trim(),
      logistics_number: logisticsNumber.trim(),
    }

    if (!payload.logistics_company || !payload.logistics_number) {
      window.alert('物流公司和物流单号不能为空')
      return
    }
  }

  if (nextStatus === 'CANCELED') {
    const reason = window.prompt('请输入取消原因', '')
    if (reason === null) return
    payload = { ...payload, reason: reason.trim() }
  }

  const confirmText = {
    PENDING_SHIP: '确认这笔订单已付款并进入待发货吗？',
    SHIPPED: '确认订单已经发货吗？',
    COMPLETED: '确认订单已经完成吗？',
    CANCELED: '确认取消该订单吗？',
  }[nextStatus] || '确认执行该操作吗？'

  if (!window.confirm(confirmText)) {
    return
  }

  const result = await updateAdminOrderStatus(item.order_id, payload)
  if (result.success) {
    await loadOrders()
    selectedOrder.value = result.data || item
    await loadOrderLogs(item.order_id)
  } else {
    window.alert(result.message || '更新失败')
  }
}

onMounted(loadOrders)
</script>
