<template>
  <section class="page-stack">
    <div class="card-grid">
      <article v-for="card in cards" :key="card.label" class="metric-card">
        <p>{{ card.label }}</p>
        <strong>{{ card.value }}</strong>
        <span>{{ card.hint }}</span>
      </article>
    </div>

    <section class="panel">
      <div class="panel-head">
        <div>
          <p class="eyebrow">管理入口</p>
          <h3>今天优先处理什么</h3>
        </div>
      </div>

      <div class="quick-grid">
        <button class="quick-card" type="button" @click="goTo('/users')">
          <strong>用户管理</strong>
          <span>审核待通过账号、查看角色分布</span>
        </button>
        <button class="quick-card" type="button" @click="goTo('/products')">
          <strong>商品审核</strong>
          <span>处理待审商品、下架违规商品</span>
        </button>
        <button class="quick-card" type="button" @click="goTo('/orders')">
          <strong>订单处理</strong>
          <span>推进付款、发货、完成、取消流程</span>
        </button>
      </div>
    </section>

    <section class="panel">
      <div class="panel-head">
        <div>
          <p class="eyebrow">操作说明</p>
          <h3>后台工作流</h3>
        </div>
      </div>

      <ol class="workflow-list">
        <li>先处理待审核用户，确认其注册状态。</li>
        <li>再审核商品，确保上架商品符合要求。</li>
        <li>最后处理订单，推动订单进入发货和完成状态。</li>
      </ol>
    </section>
  </section>
</template>

<script setup>
import { computed, onMounted, ref } from 'vue'
import { useRouter } from 'vue-router'

import { getAdminStats } from '../services/api'
import { formatNumber } from '../utils/display'

const router = useRouter()
const stats = ref({})

const cards = computed(() => [
  {
    label: '用户总数',
    value: formatNumber(stats.value.total_users),
    hint: '包含普通用户与管理员',
  },
  {
    label: '待审核用户',
    value: formatNumber(stats.value.pending_users),
    hint: '注册审查队列',
  },
  {
    label: '待审商品',
    value: formatNumber(stats.value.pending_products),
    hint: '需要管理员确认的商品',
  },
  {
    label: '待处理订单',
    value: formatNumber(stats.value.pending_orders),
    hint: '待付款或待发货订单',
  },
])

const goTo = async (path) => {
  await router.push(path)
}

onMounted(async () => {
  const result = await getAdminStats()
  if (result.success) {
    stats.value = result.data || {}
  }
})
</script>
