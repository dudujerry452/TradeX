<template>
  <section class="page-stack">
    <section class="panel">
      <div class="panel-head panel-head--split">
        <div>
          <p class="eyebrow">用户管理</p>
          <h3>注册审查与角色管理</h3>
        </div>
        <div class="toolbar-actions">
          <button class="ghost-btn" type="button" @click="resetFilters">重置</button>
          <button class="primary-btn primary-btn--sm" type="button" @click="handleSearch">搜索</button>
        </div>
      </div>

      <div class="filters-grid">
        <input v-model.trim="keyword" class="input" type="text" placeholder="搜索用户名 / 邮箱 / 姓名 / ID" @keyup.enter="handleSearch" />
        <select v-model="roleFilter" class="input">
          <option value="">全部角色</option>
          <option value="NORMAL">普通用户</option>
          <option value="ADMIN">系统管理员</option>
        </select>
        <select v-model="statusFilter" class="input">
          <option value="">全部状态</option>
          <option value="PENDING">待审核</option>
          <option value="APPROVED">审核通过</option>
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
        <table class="data-table">
          <thead>
            <tr>
              <th>用户</th>
              <th>角色</th>
              <th>审核状态</th>
              <th>联系信息</th>
              <th>注册时间</th>
              <th>操作</th>
            </tr>
          </thead>
          <tbody>
            <tr v-if="loading">
              <td colspan="6" class="table-empty">加载中...</td>
            </tr>
            <tr v-else-if="!items.length">
              <td colspan="6" class="table-empty">暂无用户数据</td>
            </tr>
            <tr v-for="item in items" :key="item.user_id">
              <td>
                <div class="table-main-cell">
                  <strong>{{ item.username }}</strong>
                  <span>{{ item.real_name }}</span>
                  <small>{{ item.user_id }}</small>
                </div>
              </td>
              <td>
                <span :class="['status-pill', `status-pill--${getRoleMeta(item.role).tone}`]">
                  {{ getRoleMeta(item.role).label }}
                </span>
              </td>
              <td>
                <span :class="['status-pill', `status-pill--${getRegisterStatusMeta(item.register_status).tone}`]">
                  {{ getRegisterStatusMeta(item.register_status).label }}
                </span>
              </td>
              <td>
                <div class="table-main-cell">
                  <span>{{ item.email }}</span>
                  <small>{{ item.phone_display || item.phone || '—' }}</small>
                </div>
              </td>
              <td>{{ formatDateTime(item.register_time) }}</td>
              <td>
                <div class="table-actions">
                  <button class="action-btn action-btn--success" type="button" @click="setRegisterStatus(item, 'APPROVED')">
                    通过
                  </button>
                  <button class="action-btn action-btn--danger" type="button" @click="setRegisterStatus(item, 'REJECTED')">
                    驳回
                  </button>
                  <button
                    class="action-btn action-btn--accent"
                    type="button"
                    @click="toggleRole(item)"
                  >
                    {{ item.role === 'ADMIN' ? '降为普通用户' : '设为管理员' }}
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

import { getAdminUsers, updateAdminUser } from '../services/api'
import { formatDateTime } from '../utils/display'

const keyword = ref('')
const roleFilter = ref('')
const statusFilter = ref('')
const loading = ref(false)
const items = ref([])
const total = ref(0)
const page = ref(1)
const pageSize = 10

const totalPages = computed(() => Math.max(1, Math.ceil(total.value / pageSize)))

const loadUsers = async () => {
  loading.value = true
  const result = await getAdminUsers({
    q: keyword.value.trim(),
    role: roleFilter.value,
    register_status: statusFilter.value,
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
  await loadUsers()
}

const resetFilters = async () => {
  keyword.value = ''
  roleFilter.value = ''
  statusFilter.value = ''
  page.value = 1
  await loadUsers()
}

const prevPage = async () => {
  if (page.value <= 1) return
  page.value -= 1
  await loadUsers()
}

const nextPage = async () => {
  if (page.value >= totalPages.value) return
  page.value += 1
  await loadUsers()
}

const setRegisterStatus = async (item, registerStatus) => {
  if (!window.confirm(`确认将 ${item.username} 的注册状态改为 ${registerStatus} 吗？`)) {
    return
  }

  const result = await updateAdminUser(item.user_id, { register_status: registerStatus })
  if (result.success) {
    await loadUsers()
  } else {
    window.alert(result.message || '更新失败')
  }
}

const toggleRole = async (item) => {
  const nextRole = item.role === 'ADMIN' ? 'NORMAL' : 'ADMIN'
  if (!window.confirm(`确认将 ${item.username} 的角色改为 ${nextRole} 吗？`)) {
    return
  }

  const result = await updateAdminUser(item.user_id, { role: nextRole })
  if (result.success) {
    await loadUsers()
  } else {
    window.alert(result.message || '更新失败')
  }
}

onMounted(loadUsers)

const getRoleMeta = (role) => {
  const map = {
    ADMIN: { label: '系统管理员', tone: 'accent' },
    NORMAL: { label: '普通用户', tone: 'muted' },
  }

  return map[role] || { label: role || '未知', tone: 'muted' }
}

const getRegisterStatusMeta = (status) => {
  const map = {
    PENDING: { label: '待审核', tone: 'warning' },
    APPROVED: { label: '审核通过', tone: 'success' },
    REJECTED: { label: '审核驳回', tone: 'danger' },
  }

  return map[status] || { label: status || '未知', tone: 'muted' }
}
</script>
