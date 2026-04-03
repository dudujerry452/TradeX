<script setup>
import { reactive } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { login } from '../config/api'
import { saveLogin } from '../utils/auth'

const router = useRouter()
const route = useRoute()

const form = reactive({
  loginMode: 'username',
  identifier: '',
  password: '',
  loading: false,
  error: '',
  success: '',
})

const getRedirectTarget = () => {
  return typeof route.query.redirect === 'string' && route.query.redirect ? route.query.redirect : '/home'
}

const persistLogin = async (result) => {
  await saveLogin(result.token, {
    user_id: result.user_id,
    username: result.username,
    role: result.role,
  })
}

const onSubmit = async () => {
  if (form.loading) return

  form.loading = true
  form.error = ''
  form.success = ''

  try {
    const result = await login({
      identifier: form.identifier,
      password: form.password,
      isEmail: form.loginMode === 'email',
    })

    if (!result.success) {
      throw new Error(result.message || '登录失败')
    }

    await persistLogin(result)
    form.success = '登录成功'
    await router.push(getRedirectTarget())
  } catch (error) {
    form.error = error instanceof Error ? error.message : '登录请求失败'
  } finally {
    form.loading = false
  }
}

const debugLogin = async () => {
  if (form.loading) return

  form.loading = true
  form.error = ''
  form.success = ''

  try {
    const result = await login({
      identifier: 'admin_root',
      password: 'hashed_admin_pw',
      isEmail: false,
    })

    if (!result.success) {
      throw new Error(result.message || '调试登录失败')
    }

    await persistLogin(result)
    form.success = '调试登录成功'
    await router.push(getRedirectTarget())
  } catch (error) {
    form.error = error instanceof Error ? error.message : '调试登录失败'
  } finally {
    form.loading = false
  }
}
</script>

<template>
  <div class="login-page">
    <section class="login-card page-card">
      <header class="login-header">
        <div class="brand-icon">TX</div>
        <div>
          <p class="eyebrow">tradeX</p>
          <h1>欢迎回来</h1>
          <p class="subtitle">使用用户名或邮箱登录，体验与 mobile 一致的账号流。</p>
        </div>
      </header>

      <div class="mode-switch">
        <button
          type="button"
          class="mode-btn"
          :class="{ active: form.loginMode === 'username' }"
          @click="form.loginMode = 'username'"
        >
          用户名登录
        </button>
        <button
          type="button"
          class="mode-btn"
          :class="{ active: form.loginMode === 'email' }"
          @click="form.loginMode = 'email'"
        >
          邮箱登录
        </button>
      </div>

      <form class="login-form" @submit.prevent="onSubmit">
        <label class="field">
          <span>{{ form.loginMode === 'email' ? 'Email Address' : 'Username' }}</span>
          <input
            v-model="form.identifier"
            :type="form.loginMode === 'email' ? 'email' : 'text'"
            :placeholder="form.loginMode === 'email' ? 'you@example.com' : '输入用户名'"
            autocomplete="username"
            required
          />
        </label>

        <label class="field">
          <span>Password</span>
          <input
            v-model="form.password"
            type="password"
            placeholder="请输入密码"
            autocomplete="current-password"
            required
          />
        </label>

        <button type="submit" class="primary-btn submit-btn" :disabled="form.loading">
          {{ form.loading ? '登录中...' : '登录' }}
        </button>

        <button type="button" class="ghost-btn submit-btn" :disabled="form.loading" @click="debugLogin">
          调试登录 (admin)
        </button>

        <p v-if="form.error" class="status error">{{ form.error }}</p>
        <p v-if="form.success" class="status success">{{ form.success }}</p>
      </form>

      <footer class="login-footer">
        <span>还没有账号？</span>
        <RouterLink to="/register" class="link">去注册</RouterLink>
      </footer>
    </section>
  </div>
</template>

<style scoped>
.login-page {
  min-height: 100vh;
  padding: 24px;
  display: grid;
  place-items: center;
  background: linear-gradient(180deg, #f2f1f8 0%, #f7f6fc 100%);
}

.login-card {
  width: min(100%, 460px);
  padding: 22px;
  display: grid;
  gap: 18px;
}

.login-header {
  display: grid;
  grid-template-columns: 64px 1fr;
  gap: 14px;
  align-items: center;
}

.brand-icon {
  width: 64px;
  height: 64px;
  border-radius: 18px;
  display: grid;
  place-items: center;
  background: linear-gradient(135deg, var(--primary), var(--primary-strong));
  color: #fff;
  font-weight: 900;
  font-size: 20px;
  letter-spacing: 0.04em;
}

.eyebrow {
  color: var(--primary);
  font-size: 13px;
  font-weight: 800;
  letter-spacing: 0.08em;
  text-transform: uppercase;
}

.login-header h1 {
  font-size: 30px;
  line-height: 1.08;
  font-weight: 900;
  margin-top: 4px;
}

.subtitle {
  margin-top: 6px;
  color: var(--text-muted);
  font-size: 14px;
  line-height: 1.6;
}

.mode-switch {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 8px;
  padding: 4px;
  border-radius: 16px;
  background: rgba(17, 19, 31, 0.04);
}

.mode-btn {
  min-height: 44px;
  border: 0;
  border-radius: 12px;
  background: transparent;
  color: #4f5568;
  font-weight: 800;
}

.mode-btn.active {
  background: #fff;
  color: var(--primary);
  box-shadow: 0 10px 18px rgba(16, 24, 40, 0.08);
}

.login-form {
  display: grid;
  gap: 14px;
}

.field {
  display: grid;
  gap: 8px;
}

.field span {
  font-size: 14px;
  font-weight: 800;
  color: #1f2937;
}

.field input {
  width: 100%;
  border: 1px solid rgba(17, 19, 31, 0.08);
  border-radius: 14px;
  background: rgba(255, 255, 255, 0.92);
  padding: 14px 16px;
  outline: none;
}

.submit-btn {
  width: 100%;
  min-height: 52px;
}

.login-footer {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 8px;
  color: var(--text-muted);
  font-size: 14px;
}

.link {
  color: var(--primary);
  font-weight: 800;
  text-decoration: none;
}

.status.success {
  color: #067647;
}

.status.error {
  color: var(--danger);
}

@media (max-width: 720px) {
  .login-page {
    padding: 14px;
  }

  .login-card {
    padding: 16px;
  }

  .login-header h1 {
    font-size: 24px;
  }
}
</style>
