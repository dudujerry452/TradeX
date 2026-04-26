<template>
  <div class="login-page">
    <section class="login-hero">
      <div class="hero-badge">TradeX Admin</div>
      <h1>后台管理控制台</h1>
      <p>
        独立项目，复用同一套后端接口，集中处理用户审核、商品审查和订单流转。
      </p>

      <div class="hero-points">
        <div>
          <strong>用户管理</strong>
          <span>角色、审核状态、基础资料</span>
        </div>
        <div>
          <strong>商品审核</strong>
          <span>待审、通过、下架、驳回</span>
        </div>
        <div>
          <strong>订单处理</strong>
          <span>确认付款、发货、完成、取消</span>
        </div>
      </div>
    </section>

    <section class="login-card">
      <h2>管理员登录</h2>
      <p class="login-subtitle">使用已有的 TradeX 账号登录，只有系统管理员可以进入。</p>

      <form class="auth-form" @submit.prevent="handleSubmit">
        <label>
          <span>账号或邮箱</span>
          <input
            v-model.trim="identifier"
            class="input"
            type="text"
            placeholder="admin_root 或 admin@example.com"
            autocomplete="username"
          />
        </label>

        <label>
          <span>密码</span>
          <input
            v-model="password"
            class="input"
            type="password"
            placeholder="请输入密码"
            autocomplete="current-password"
          />
        </label>

        <p v-if="errorMessage" class="form-error">{{ errorMessage }}</p>

        <button class="primary-btn" type="submit" :disabled="loading">
          {{ loading ? '登录中...' : '进入后台' }}
        </button>

        <p class="login-footnote">
          提示：开发环境下默认通过 Vite 代理访问后端 `/api`。
        </p>
      </form>
    </section>
  </div>
</template>

<script setup>
import { ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'

import { saveLogin } from '../services/auth'
import { loginAdmin } from '../services/api'

const router = useRouter()
const route = useRoute()

const identifier = ref('')
const password = ref('')
const loading = ref(false)
const errorMessage = ref('')

const handleSubmit = async () => {
  if (!identifier.value.trim() || !password.value) {
    errorMessage.value = '请输入账号和密码'
    return
  }

  loading.value = true
  errorMessage.value = ''

  const result = await loginAdmin({
    identifier: identifier.value.trim(),
    password: password.value,
  })

  loading.value = false

  if (!result.success) {
    errorMessage.value = result.message || '登录失败'
    return
  }

  await saveLogin(result.token, result.user)

  const redirectTarget = route.query.redirect ? String(route.query.redirect) : '/dashboard'
  await router.push(redirectTarget || '/dashboard')
}
</script>
