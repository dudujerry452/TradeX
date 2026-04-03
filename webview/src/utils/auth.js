const TOKEN_KEY = 'tradex_token'
const USER_KEY = 'tradex_user'

const hasWindow = typeof window !== 'undefined'

const readStorage = (key) => {
  if (!hasWindow) return null
  return window.localStorage.getItem(key)
}

const writeStorage = (key, value) => {
  if (!hasWindow) return
  window.localStorage.setItem(key, value)
}

const removeStorage = (key) => {
  if (!hasWindow) return
  window.localStorage.removeItem(key)
}

const decodeBase64Url = (input) => {
  const normalized = input.replace(/-/g, '+').replace(/_/g, '/')
  const padded = normalized.padEnd(Math.ceil(normalized.length / 4) * 4, '=')

  if (typeof atob === 'function') {
    const binary = atob(padded)
    const bytes = Uint8Array.from(binary, (character) => character.charCodeAt(0))
    return new TextDecoder().decode(bytes)
  }

  if (typeof Buffer !== 'undefined') {
    return Buffer.from(padded, 'base64').toString('utf-8')
  }

  return ''
}

const readTokenPayload = (token) => {
  if (!token || typeof token !== 'string') return null
  const parts = token.split('.')
  if (parts.length < 2) return null

  try {
    return JSON.parse(decodeBase64Url(parts[1]))
  } catch {
    return null
  }
}

const isTokenExpired = (token) => {
  const payload = readTokenPayload(token)
  if (!payload?.exp) return false
  return Date.now() >= payload.exp * 1000
}

export const saveLogin = async (token, userData) => {
  writeStorage(TOKEN_KEY, token)
  writeStorage(USER_KEY, JSON.stringify(userData))
}

export const getToken = async () => {
  const token = readStorage(TOKEN_KEY)
  if (!token) return null

  if (isTokenExpired(token)) {
    await clearLogin()
    return null
  }

  return token
}

export const getUser = async () => {
  const raw = readStorage(USER_KEY)
  if (!raw) return null

  try {
    return JSON.parse(raw)
  } catch {
    return null
  }
}

export const getUserId = async () => {
  const user = await getUser()
  return user?.user_id || ''
}

export const getUsername = async () => {
  const user = await getUser()
  return user?.username || ''
}

export const clearLogin = async () => {
  removeStorage(TOKEN_KEY)
  removeStorage(USER_KEY)
}

export const isLoggedIn = async () => Boolean(await getToken())

export const getAuthHeaders = async (extraHeaders = {}) => {
  const token = await getToken()

  return {
    'Content-Type': 'application/json',
    ...(token ? { Authorization: `Bearer ${token}` } : {}),
    ...extraHeaders,
  }
}
