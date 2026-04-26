export const formatNumber = (value) => {
  return new Intl.NumberFormat('zh-CN').format(Number(value || 0))
}

export const formatMoney = (value) => {
  return new Intl.NumberFormat('zh-CN', {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  }).format(Number(value || 0))
}

export const formatDateTime = (value) => {
  if (!value) return '—'
  const date = new Date(value)
  if (Number.isNaN(date.getTime())) return '—'

  return new Intl.DateTimeFormat('zh-CN', {
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
  }).format(date)
}

const buildMeta = (label, tone) => ({ label, tone })

export const getRoleMeta = (role) => {
  const map = {
    ADMIN: buildMeta('系统管理员', 'accent'),
    NORMAL: buildMeta('普通用户', 'muted'),
  }

  return map[role] || buildMeta(role || '未知', 'muted')
}

export const getRegisterStatusMeta = (status) => {
  const map = {
    PENDING: buildMeta('待审核', 'warning'),
    APPROVED: buildMeta('审核通过', 'success'),
    REJECTED: buildMeta('审核驳回', 'danger'),
  }

  return map[status] || buildMeta(status || '未知', 'muted')
}

export const getProductStatusMeta = (status) => {
  const map = {
    PENDING: buildMeta('待审核', 'warning'),
    APPROVED: buildMeta('审核通过', 'success'),
    OFF_SHELF: buildMeta('已下架', 'muted'),
    REJECTED: buildMeta('审核驳回', 'danger'),
  }

  return map[status] || buildMeta(status || '未知', 'muted')
}

export const getOrderStatusMeta = (status) => {
  const map = {
    PENDING_PAY: buildMeta('待付款', 'warning'),
    PENDING_SHIP: buildMeta('待发货', 'accent'),
    SHIPPED: buildMeta('已发货', 'info'),
    COMPLETED: buildMeta('已完成', 'success'),
    CANCELED: buildMeta('已取消', 'danger'),
  }

  return map[status] || buildMeta(status || '未知', 'muted')
}
