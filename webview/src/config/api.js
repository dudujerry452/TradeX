import { getAuthHeaders, getToken } from '../utils/auth'

// 开发时：Vite 代理将 /api/* 转发到 127.0.0.1:8000，浏览器只看到同源请求，无 CORS 问题
// 生产时：前端由 Django 静态文件服务，前后端同域，相对路径同样有效
export const API_BASE_URL = ''

export const LOGIN_API_URL = `${API_BASE_URL}/api/login`
export const REGISTER_API_URL = `${API_BASE_URL}/api/users/`
export const PRODUCTS_API_URL = `${API_BASE_URL}/api/products/`
export const RAG_CHAT_STREAM_API_URL = `${API_BASE_URL}/api/rag/chat/stream`
export const getProductDetailApiUrl = (productId) =>
	`${API_BASE_URL}/api/products/${encodeURIComponent(productId)}/`

const CATEGORIES_API_URL = `${API_BASE_URL}/api/categories/`
const FAVORITES_API_URL = `${API_BASE_URL}/api/product-favorites/`
const RECOMMENDATIONS_API_BASE_URL = `${API_BASE_URL}/api/recommendations/`

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

const normalizeArray = (value) => (Array.isArray(value) ? value : [])

const normalizeProductItem = (item) => {
	if (!item || typeof item !== 'object') {
		return item
	}

	return {
		...item,
		category: item.category_name || item.category || '',
		category_id: item.category_id || item.category || '',
	}
}

const normalizeProductList = (value) => normalizeArray(value).map(normalizeProductItem)

export const login = async ({ identifier, password, isEmail = false }) => {
	const payload = {
		password,
	}

	if (isEmail) {
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
	return {
		success: true,
		token: data.token || '',
		user_id: data.user_id || '',
		username: data.username || '',
		role: data.role || '',
	}
}

export const register = async (payload) => {
	return requestJson(REGISTER_API_URL, {
		method: 'POST',
		body: payload,
	})
}

export const getProducts = async ({ page = 1, pageSize = 20, category } = {}) => {
	const result = await requestJson(PRODUCTS_API_URL)
	if (!result.success) {
		return result
	}

	let items = normalizeProductList(result.data)
	if (category) {
		items = items.filter((item) => item.category_id === category || item.category === category)
	}

	const startIndex = Math.max(page - 1, 0) * pageSize

	return {
		success: true,
		data: {
			items: items.slice(startIndex, startIndex + pageSize),
		},
	}
}

export const getProductDetail = async (productId) => {
	const result = await requestJson(getProductDetailApiUrl(productId))
	if (!result.success) {
		return result
	}

	return {
		success: true,
		data: normalizeProductItem(result.data),
	}
}

export const getProductTags = async (productId) => {
	return requestJson(`${API_BASE_URL}/api/products/${encodeURIComponent(productId)}/tags/`)
}

export const getUserTagPreferences = async (userId) => {
	return requestJson(`${API_BASE_URL}/api/users/${encodeURIComponent(userId)}/tag-preferences/`, {
		auth: true,
	})
}

export const getUserFavorites = async (userId) => {
	return requestJson(`${API_BASE_URL}/api/users/${encodeURIComponent(userId)}/favorites/`, {
		auth: true,
	})
}

export const addFavorite = async (userId, productId) => {
	return requestJson(FAVORITES_API_URL, {
		method: 'POST',
		auth: true,
		body: {
			user_id: userId,
			product_id: productId,
		},
	})
}

export const removeFavorite = async (userId, productId) => {
	return requestJson(
		appendQuery(`${API_BASE_URL}/api/product-favorites/delete/`, {
			user_id: userId,
			product_id: productId,
		}),
		{
			method: 'DELETE',
			auth: true,
		},
	)
}

export const checkFavorite = async (userId, productId) => {
	const result = await requestJson(
		appendQuery(`${API_BASE_URL}/api/product-favorites/check/`, {
			user_id: userId,
			product_id: productId,
		}),
		{
			auth: true,
		},
	)

	if (!result.success) {
		return result
	}

	return {
		success: true,
		isFavorited: Boolean(result.data?.is_favorited),
	}
}

export const getCategories = async () => {
	const result = await requestJson(CATEGORIES_API_URL)
	if (!result.success) {
		return result
	}

	const categories = normalizeArray(result.data).map((category) => ({
		id: category.category_id,
		name: category.name,
		description: category.description || '',
		sort_order: category.sort_order ?? 0,
		is_active: category.is_active ?? true,
	}))

	return {
		success: true,
		data: [{ id: 'all', name: '全部' }, ...categories],
	}
}

export const getPersonalizedRecommendations = async ({ userId, limit = 10, offset = 0 } = {}) => {
	const result = await requestJson(
		appendQuery(`${RECOMMENDATIONS_API_BASE_URL}personalized/`, {
			user_id: userId,
			limit,
			offset,
		}),
		{
			auth: true,
		},
	)

	if (!result.success) {
		return result
	}

	return {
		success: true,
		data: normalizeProductList(result.data),
	}
}

export const getTrendingRecommendations = async ({ limit = 10, offset = 0 } = {}) => {
	const result = await requestJson(
		appendQuery(`${RECOMMENDATIONS_API_BASE_URL}trending/`, {
			limit,
			offset,
		}),
	)

	if (!result.success) {
		return result
	}

	return {
		success: true,
		data: normalizeProductList(result.data),
	}
}

export const getSimilarProducts = async ({ productId, limit = 5 } = {}) => {
	const result = await requestJson(
		appendQuery(`${RECOMMENDATIONS_API_BASE_URL}similar/`, {
			product_id: productId,
			limit,
		}),
	)

	if (!result.success) {
		return result
	}

	return {
		success: true,
		data: normalizeProductList(result.data),
	}
}

export const searchProducts = async ({ query = '', category, limit = 10, offset = 0, token } = {}) => {
	const effectiveToken = token || (await getToken())
	const result = await requestJson(
		appendQuery(`${API_BASE_URL}/api/products/search/`, {
			q: query,
			category,
			limit,
			offset,
			token: effectiveToken,
		}),
	)

	if (!result.success) {
		return result
	}

	return {
		success: true,
		data: normalizeProductList(result.data),
	}
}

export const recordProductView = async (productId) => {
	return requestJson(`${API_BASE_URL}/api/products/${encodeURIComponent(productId)}/view/`, {
		method: 'POST',
		auth: true,
	})
}

export const createProduct = async (productData) => {
	return requestJson(PRODUCTS_API_URL, {
		method: 'POST',
		auth: true,
		body: productData,
	})
}
