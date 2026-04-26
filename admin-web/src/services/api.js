import { clearLogin, getAuthHeaders } from './auth'

export const API_BASE_URL = import.meta.env.VITE_API_BASE_URL || ''

export const LOGIN_API_URL = `${API_BASE_URL}/api/login`
export const ADMIN_STATS_API_URL = `${API_BASE_URL}/api/admin/stats/`
export const ADMIN_USERS_API_URL = `${API_BASE_URL}/api/admin/users/`
export const ADMIN_PRODUCTS_API_URL = `${API_BASE_URL}/api/admin/products/`
export const ADMIN_ORDERS_API_URL = `${API_BASE_URL}/api/admin/orders/`

const appendQuery = (url, params = {}) => {
  const searchParams = new URLSearchParams()

  Object.entries(params).forEach(([key, value]) => {
    if (value === undefined || value === null || value === '') {
      return
    }

    searchParams.set(key, String(value))
  })

  const queryString = searchParams.toString()
  return queryString ? `${url}?${queryString}` : url
}

const parseResponsePayload = async (response) => {
  const text = await response.text()
  if (!text) {
    return null
  }

  try {
    return JSON.parse(text)
  } catch {
    return text
  }
}

const extractErrorMessage = (payload, fallbackMessage) => {
  if (!payload) {
    return fallbackMessage
  }

  if (typeof payload === 'string') {
    return payload
  }

  if (Array.isArray(payload)) {
    const messages = payload
      .map((item) => extractErrorMessage(item, ''))
      .filter(Boolean)

    return messages.length ? messages.join(', ') : fallbackMessage
  }

  if (typeof payload === 'object') {
    if (typeof payload.detail === 'string') {
      return payload.detail
    }

    if (Array.isArray(payload.detail)) {
      const messages = payload.detail
        .map((item) => extractErrorMessage(item, ''))
        .filter(Boolean)

      return messages.length ? messages.join(', ') : fallbackMessage
    }

    if (typeof payload.message === 'string') {
      return payload.message
    }

    if (typeof payload.msg === 'string') {
      return payload.msg
    }
  }

  return fallbackMessage
}

const requestJson = async (url, { method = 'GET', body, headers = {}, auth = false } = {}) => {
  try {
    let requestHeaders = { ...headers }

    if (auth) {
      requestHeaders = await getAuthHeaders(requestHeaders)
    } else if (body !== undefined && !(body instanceof FormData) && !requestHeaders['Content-Type']) {
      requestHeaders['Content-Type'] = 'application/json'
    }

    const requestBody =
      body === undefined
        ? undefined
        : body instanceof FormData || typeof body === 'string'
          ? body
          : JSON.stringify(body)

    const response = await fetch(url, {
      method,
      headers: requestHeaders,
      body: requestBody,
    })

    const payload = await parseResponsePayload(response)
    if (!response.ok) {
      return {
        success: false,
        status: response.status,
        message: extractErrorMessage(payload, `请求失败 (${response.status})`),
        detail: payload,
      }
    }

    return {
      success: true,
      status: response.status,
      data: payload,
    }
  } catch (error) {
    return {
      success: false,
      message: error instanceof Error ? `网络连接错误: ${error.message}` : '网络连接错误',
    }
  }
}

export const loginAdmin = async ({ identifier, password }) => {
  const payload = { password }
  if (identifier.includes('@')) {
    payload.email = identifier
  } else {
    payload.username = identifier
  }

  const result = await requestJson(LOGIN_API_URL, {
    method: 'POST',
    body: payload,
  })

  if (!result.success) {
    return result
  }

  const data = result.data || {}
  if (data.role !== 'ADMIN') {
    await clearLogin()
    return {
      success: false,
      message: '当前账号不是管理员，无法登录后台',
    }
  }

  return {
    success: true,
    token: data.token || '',
    user: {
      user_id: data.user_id || '',
      username: data.username || '',
      role: data.role || '',
    },
  }
}

export const getAdminStats = async () => {
  return requestJson(ADMIN_STATS_API_URL, { auth: true })
}

export const getAdminUsers = async (params = {}) => {
  return requestJson(appendQuery(ADMIN_USERS_API_URL, params), { auth: true })
}

export const updateAdminUser = async (userId, payload) => {
  return requestJson(`${ADMIN_USERS_API_URL}${encodeURIComponent(userId)}/`, {
    method: 'PATCH',
    auth: true,
    body: payload,
  })
}

export const getAdminProducts = async (params = {}) => {
  return requestJson(appendQuery(ADMIN_PRODUCTS_API_URL, params), { auth: true })
}

export const updateAdminProductStatus = async (productId, payload) => {
  return requestJson(`${ADMIN_PRODUCTS_API_URL}${encodeURIComponent(productId)}/status/`, {
    method: 'PATCH',
    auth: true,
    body: payload,
  })
}

export const getAdminOrders = async (params = {}) => {
  return requestJson(appendQuery(ADMIN_ORDERS_API_URL, params), { auth: true })
}

export const getAdminOrderDetail = async (orderId) => {
  return requestJson(`${ADMIN_ORDERS_API_URL}${encodeURIComponent(orderId)}/`, { auth: true })
}

export const getAdminOrderLogs = async (orderId) => {
  return requestJson(`${ADMIN_ORDERS_API_URL}${encodeURIComponent(orderId)}/logs/`, { auth: true })
}

export const updateAdminOrderStatus = async (orderId, payload) => {
  return requestJson(`${ADMIN_ORDERS_API_URL}${encodeURIComponent(orderId)}/status/`, {
    method: 'PATCH',
    auth: true,
    body: payload,
  })
}
