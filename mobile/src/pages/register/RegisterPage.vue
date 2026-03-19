<script setup>
import { reactive } from 'vue'
import { REGISTER_API_URL } from '../../config/api'
import { floatingIcons } from '../../config/loginFloatingIcons'
import bagIcon from '../../assets/login/bag.svg'
import mailIcon from '../../assets/login/mail.svg'
import lockIcon from '../../assets/login/lock.svg'

const form = reactive({
  email: '',
  username: '',
  realName: '',
  idCard: '',
  phone: '',
  address: '',
  password: '',
  confirmPassword: '',
  loading: false,
  error: '',
  success: '',
})

const onSubmit = () => {
  if (form.loading) return
  form.error = ''
  form.success = ''

  if (form.password !== form.confirmPassword) {
    form.error = '两次密码不一致'
    return
  }

  form.loading = true

  uni.request({
    url: REGISTER_API_URL,
    method: 'POST',
    header: { 'Content-Type': 'application/json' },
    data: {
      email: form.email,
      username: form.username,
      encrypted_password: form.password,
      real_name: form.realName,
      id_card: form.idCard,
      phone: form.phone,
      address: form.address,
    },
    success: (res) => {
      if (res.statusCode === 201) {
        form.success = '注册成功，请登录'
        setTimeout(() => {
          uni.redirectTo({ url: '/pages/login/UserLogin' })
        }, 1000)
      } else {
        form.error = res.statusCode === 400 ? '邮箱/用户名/身份证可能已存在，或字段不合法' : '注册失败'
      }
    },
    fail: () => {
      form.error = '注册请求失败，请检查网络'
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
      :style="{ top: icon.top, left: icon.left, width: icon.size }"
    >
      <image :src="icon.src" mode="aspectFit" />
    </view>

    <view class="login-card">
      <view class="login-header">
        <view class="brand-icon">
          <image :src="bagIcon" mode="aspectFit" class="brand-img" />
        </view>
        <text class="title">Create <text class="accent">tradeX</text></text>
        <text class="subtitle">Join and start your shopping journey</text>
      </view>

      <view class="field">
        <text class="label">Email Address</text>
        <view class="input-wrap">
          <image :src="mailIcon" mode="aspectFit" class="input-icon" />
          <input v-model="form.email" type="text" placeholder="you@example.com" class="input" />
        </view>
      </view>

      <view class="field">
        <text class="label">Username</text>
        <view class="input-wrap">
          <image :src="mailIcon" mode="aspectFit" class="input-icon" />
          <input v-model="form.username" type="text" placeholder="Enter username" class="input" />
        </view>
      </view>

      <view class="field">
        <text class="label">Real Name</text>
        <view class="input-wrap">
          <image :src="mailIcon" mode="aspectFit" class="input-icon" />
          <input v-model="form.realName" type="text" placeholder="Enter real name" class="input" />
        </view>
      </view>

      <view class="field">
        <text class="label">ID Card</text>
        <view class="input-wrap">
          <image :src="mailIcon" mode="aspectFit" class="input-icon" />
          <input v-model="form.idCard" type="text" maxlength="18" placeholder="18-digit id card" class="input" />
        </view>
      </view>

      <view class="field">
        <text class="label">Phone</text>
        <view class="input-wrap">
          <image :src="mailIcon" mode="aspectFit" class="input-icon" />
          <input v-model="form.phone" type="number" placeholder="Enter phone number" class="input" />
        </view>
      </view>

      <view class="field">
        <text class="label">Address</text>
        <view class="input-wrap">
          <image :src="mailIcon" mode="aspectFit" class="input-icon" />
          <input v-model="form.address" type="text" placeholder="Enter shipping address" class="input" />
        </view>
      </view>

      <view class="field">
        <text class="label">Password</text>
        <view class="input-wrap">
          <image :src="lockIcon" mode="aspectFit" class="input-icon" />
          <input v-model="form.password" password placeholder="Create a password" class="input" />
        </view>
      </view>

      <view class="field">
        <text class="label">Confirm Password</text>
        <view class="input-wrap">
          <image :src="lockIcon" mode="aspectFit" class="input-icon" />
          <input v-model="form.confirmPassword" password placeholder="Confirm your password" class="input" />
        </view>
      </view>

      <button class="submit-btn" :disabled="form.loading" @tap="onSubmit">
        {{ form.loading ? 'Creating Account...' : 'Create Account' }}
      </button>

      <text v-if="form.error" class="status error">{{ form.error }}</text>
      <text v-if="form.success" class="status success">{{ form.success }}</text>

      <view class="login-footer">
        <text>Already have an account? </text>
        <text class="link" @tap="() => uni.redirectTo({ url: '/pages/login/UserLogin' })">Back to sign in</text>
      </view>
    </view>
  </view>
</template>

<style scoped>
.login-page {
  min-height: 100vh;
  display: flex;
  align-items: flex-start;
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

.brand-img { width: 31px; height: 31px; }

.title {
  font-size: 36px;
  font-weight: 800;
  color: #11131f;
  margin-bottom: 8px;
}

.accent { color: #d4a373; }

.subtitle {
  font-size: 14px;
  font-weight: 600;
  color: #475569;
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

.input-icon { width: 22px; height: 22px; flex-shrink: 0; }

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
