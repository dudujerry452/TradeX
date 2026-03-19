<script setup>
import { reactive } from 'vue'
import { LOGIN_API_URL } from '../../config/api'
import { floatingIcons } from '../../config/loginFloatingIcons'
import bagIcon from '../../assets/login/bag.svg'
import mailIcon from '../../assets/login/mail.svg'
import lockIcon from '../../assets/login/lock.svg'

const form = reactive({
  loginMode: 'username',
  identifier: '',
  password: '',
  loading: false,
  error: '',
  success: '',
})

const onSubmit = async () => {
  if (form.loading) return

  form.loading = true
  form.error = ''
  form.success = ''

  const loginPayload = { password: form.password }
  if (form.loginMode === 'email') {
    loginPayload.email = form.identifier
  } else {
    loginPayload.username = form.identifier
  }

  uni.request({
    url: LOGIN_API_URL,
    method: 'POST',
    header: { 'Content-Type': 'application/json' },
    data: loginPayload,
    success: (res) => {
      if (res.statusCode >= 200 && res.statusCode < 300) {
        form.success = '登录成功'
        uni.redirectTo({ url: '/pages/home/HomePage' })
      } else {
        form.error = res.data?.detail || `登录失败: ${res.statusCode}`
      }
    },
    fail: () => {
      form.error = '登录请求失败，请检查网络'
    },
    complete: () => {
      form.loading = false
    },
  })
}
</script>

<template>
  <view class="login-page">
    <view class="bg-dots" />
    <view
      v-for="(icon, index) in floatingIcons"
      :key="`${icon.top}-${icon.left}-${index}`"
      class="floating-icon"
      :style="{
        top: icon.top,
        left: icon.left,
        width: icon.size,
      }"
    >
      <image :src="icon.src" mode="aspectFit" />
    </view>

    <view class="login-card">
      <view class="login-header">
        <view class="brand-icon">
          <image :src="bagIcon" mode="aspectFit" class="brand-img" />
        </view>
        <text class="title">Welcome to <text class="accent">tradeX</text></text>
        <text class="subtitle">Sign in to continue shopping</text>
      </view>

      <view class="mode-switch">
        <view
          class="mode-btn"
          :class="{ active: form.loginMode === 'username' }"
          @tap="form.loginMode = 'username'"
        >
          <text>用户名登录</text>
        </view>
        <view
          class="mode-btn"
          :class="{ active: form.loginMode === 'email' }"
          @tap="form.loginMode = 'email'"
        >
          <text>邮箱登录</text>
        </view>
      </view>

      <view class="field">
        <text class="label">{{ form.loginMode === 'email' ? 'Email Address' : 'Username' }}</text>
        <view class="input-wrap">
          <image :src="mailIcon" mode="aspectFit" class="input-icon" />
          <input
            v-model="form.identifier"
            :type="form.loginMode === 'email' ? 'text' : 'text'"
            :placeholder="form.loginMode === 'email' ? 'you@example.com' : 'Enter username'"
            class="input"
          />
        </view>
      </view>

      <view class="field">
        <text class="label">Password</text>
        <view class="input-wrap">
          <image :src="lockIcon" mode="aspectFit" class="input-icon" />
          <input
            v-model="form.password"
            password
            placeholder="Enter your password"
            class="input"
          />
        </view>
      </view>

      <button class="submit-btn" :disabled="form.loading" @tap="onSubmit">
        {{ form.loading ? 'Signing In...' : 'Sign In' }}
      </button>

      <text v-if="form.error" class="status error">{{ form.error }}</text>
      <text v-if="form.success" class="status success">{{ form.success }}</text>

      <view class="login-footer">
        <text>Don't have an account? </text>
        <text class="link" @tap="() => uni.navigateTo({ url: '/pages/register/RegisterPage' })">Sign up for free</text>
      </view>
    </view>
  </view>
</template>

<style scoped>
.login-page {
  min-height: 100vh;
  display: flex;
  align-items: center;
  justify-content: center;
  position: relative;
  overflow: hidden;
  padding: 26px;
  background: linear-gradient(180deg, #f2f1f8 0%, #f7f6fc 100%);
}

.bg-dots {
  position: fixed;
  top: 0; left: 0; right: 0; bottom: 0;
  z-index: 0;
  opacity: 0.4;
  background-image: radial-gradient(circle, rgba(153, 158, 184, 0.42) 1px, transparent 1px);
  background-size: 13px 13px;
}

.floating-icon {
  position: fixed;
  z-index: 0;
  opacity: 0.7;
}

.floating-icon image {
  width: 100%;
  height: 100%;
}

.login-card {
  width: 100%;
  max-width: 430px;
  border-radius: 20px;
  background: #f7f7fa;
  box-shadow: 0 20px 40px rgba(16, 24, 40, 0.1);
  padding: 30px 30px 26px;
  position: relative;
  z-index: 1;
}

.login-header {
  text-align: center;
  margin-bottom: 24px;
  display: flex;
  flex-direction: column;
  align-items: center;
}

.brand-icon {
  width: 68px;
  height: 68px;
  border-radius: 18px;
  display: flex;
  align-items: center;
  justify-content: center;
  background: linear-gradient(150deg, #d0661a 0%, #e09018 100%);
  margin-bottom: 16px;
}

.brand-img {
  width: 31px;
  height: 31px;
}

.title {
  font-size: 36px;
  font-weight: 800;
  color: #11131f;
  margin-bottom: 8px;
}

.accent {
  color: #d4a373;
}

.subtitle {
  font-size: 14px;
  font-weight: 600;
  color: #475569;
}

.mode-switch {
  display: flex;
  background: #ececf0;
  border-radius: 12px;
  padding: 4px;
  margin-bottom: 16px;
}

.mode-btn {
  flex: 1;
  height: 38px;
  border-radius: 9px;
  display: flex;
  align-items: center;
  justify-content: center;
}

.mode-btn text {
  font-size: 14px;
  font-weight: 700;
  color: #4a4f63;
}

.mode-btn.active {
  background: #fff;
  box-shadow: 0 3px 8px rgba(30, 38, 66, 0.12);
}

.mode-btn.active text {
  color: #11131f;
}

.field {
  display: flex;
  flex-direction: column;
  gap: 8px;
  margin-bottom: 16px;
}

.label {
  font-size: 14px;
  font-weight: 700;
  color: #202124;
}

.input-wrap {
  height: 50px;
  border-radius: 12px;
  background: #ececf0;
  display: flex;
  align-items: center;
  padding: 0 13px;
}

.input-icon {
  width: 22px;
  height: 22px;
  flex-shrink: 0;
}

.input {
  flex: 1;
  font-size: 15px;
  font-weight: 500;
  color: #464c5f;
  padding: 0 11px;
  background: transparent;
}

.submit-btn {
  margin-top: 6px;
  border-radius: 12px;
  height: 50px;
  font-weight: 700;
  font-size: 16px;
  color: white;
  background: #020226;
  border: none;
  width: 100%;
}

.status {
  display: block;
  margin-top: 8px;
  font-size: 13px;
  font-weight: 600;
  text-align: center;
}

.error { color: #b42318; }
.success { color: #0d7a33; }

.login-footer {
  margin-top: 24px;
  font-size: 14px;
  font-weight: 600;
  color: #475569;
  display: flex;
  justify-content: center;
}

.link {
  color: #1f56ef;
  font-weight: 700;
  margin-left: 4px;
}
</style>
