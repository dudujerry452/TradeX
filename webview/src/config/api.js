// 开发时：Vite 代理将 /api/* 转发到 127.0.0.1:8000，浏览器只看到同源请求，无 CORS 问题
// 生产时：前端由 Django 静态文件服务，前后端同域，相对路径同样有效
export const API_BASE_URL = ''

export const LOGIN_API_URL = `${API_BASE_URL}/api/login`
export const REGISTER_API_URL = `${API_BASE_URL}/api/users/`
export const PRODUCTS_API_URL = `${API_BASE_URL}/api/products/`
export const RAG_CHAT_STREAM_API_URL = `${API_BASE_URL}/api/rag/chat/stream`
export const getProductDetailApiUrl = (productId) => `${API_BASE_URL}/api/products/${encodeURIComponent(productId)}/`
