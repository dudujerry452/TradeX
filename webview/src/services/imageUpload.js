import { API_BASE_URL } from '../config/api'
import { getToken } from '../utils/auth'

const MAX_UPLOAD_SIZE = 10 * 1024 * 1024
const ALLOWED_TYPES = new Set(['image/jpeg', 'image/png', 'image/webp', 'image/gif'])

const chooseLocalImageFile = () =>
  new Promise((resolve, reject) => {
    if (typeof document === 'undefined') {
      reject(new Error('当前环境不支持本地文件选择'))
      return
    }

    const input = document.createElement('input')
    input.type = 'file'
    input.accept = 'image/*'
    input.style.display = 'none'

    let settled = false

    const resolveOnce = (file) => {
      if (settled) return
      settled = true
      cleanup()
      resolve(file || null)
    }

    const cleanup = () => {
      window.removeEventListener('focus', handleWindowFocus)
      input.removeEventListener('change', handleChange)
      input.value = ''
      input.remove()
    }

    const handleChange = () => {
      const file = input.files?.[0]
      resolveOnce(file || null)
    }

    const handleWindowFocus = () => {
      resolveOnce(input.files?.[0] || null)
    }

    input.addEventListener('change', handleChange)

    document.body.appendChild(input)
    input.click()

    window.addEventListener('focus', handleWindowFocus, { once: true })
  })

export const uploadImage = async () => {
  const token = await getToken()
  if (!token) {
    return { success: false, message: '请先登录' }
  }

  const file = await chooseLocalImageFile()
  if (!file) {
    return { success: false, message: '未选择图片' }
  }

  if (!ALLOWED_TYPES.has(file.type)) {
    return { success: false, message: '仅支持 jpeg、png、webp、gif 图片' }
  }

  if (file.size > MAX_UPLOAD_SIZE) {
    return { success: false, message: '图片大小不能超过 10MB' }
  }

  const formData = new FormData()
  formData.append('file', file, file.name || 'image.jpg')

  try {
    const response = await fetch(`${API_BASE_URL}/api/uploads/image/`, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${token}`,
      },
      body: formData,
    })

    const payload = await response.json().catch(() => ({}))

    if (!response.ok) {
      return {
        success: false,
        message: payload.detail || payload.message || `上传失败 (${response.status})`,
      }
    }

    return {
      success: true,
      url: payload.url || '',
      key: payload.key || '',
      filename: payload.filename || file.name || 'image.jpg',
    }
  } catch (error) {
    return {
      success: false,
      message: error instanceof Error ? `网络连接错误: ${error.message}` : '网络连接错误',
    }
  }
}

export const supportsImagePicker = true
