// 修改 API_BASE_URL 为后端实际地址（开发时填写本机局域网 IP）
export const API_BASE_URL = 'http://127.0.0.1:8000'

export const LOGIN_API_URL = `${API_BASE_URL}/api/login`
export const REGISTER_API_URL = `${API_BASE_URL}/api/users/`
export const PRODUCTS_API_URL = `${API_BASE_URL}/api/products/`
export const getProductDetailApiUrl = (productId) => `${API_BASE_URL}/api/products/${encodeURIComponent(productId)}/`
