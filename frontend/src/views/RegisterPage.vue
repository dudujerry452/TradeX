<script setup>
import { reactive } from 'vue'
import { useRouter } from 'vue-router'
import { REGISTER_API_URL } from '../config/api'
import { floatingIcons } from '../config/loginFloatingIcons'
import bagIcon from '../assets/login/bag.svg'
import mailIcon from '../assets/login/mail.svg'
import lockIcon from '../assets/login/lock.svg'
import eyeIcon from '../assets/login/eye.svg'

const form = reactive({
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

const router = useRouter()

const onSubmit = async () => {
  if (form.loading) return

  form.error = ''
  form.success = ''

  if (form.password !== form.confirmPassword) {
    form.error = '两次密码不一致'
    return
  }


  form.loading = true

  try {
    const response = await fetch(REGISTER_API_URL, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        username: form.username,
        encrypted_password: form.password, //这里暂时没有加密
        real_name: form.realName,
        id_card: form.idCard,
        phone: form.phone,
        address: form.address,
      }),
    })

    if (!response.ok) {
      form.error = response.status === 400 ? '用户名或身份证已存在，或字段不合法' : '注册失败'
      return
    }

    form.success = '注册成功，请登录'
    await new Promise((resolve) => setTimeout(resolve, 1000))
    await router.push('/login')
  } catch (error) {
    form.error = error instanceof Error ? error.message : '注册请求失败'
  } finally {
    form.loading = false
  }
}
</script>

<template>
  <div class="login-page">
    <div class="bg-dots" aria-hidden="true"></div>
    <div
      v-for="(icon, index) in floatingIcons"
      :key="`${icon.top}-${icon.left}-${index}`"
      class="floating-icon"
      :style="{
        top: icon.top,
        left: icon.left,
        width: icon.size,
        '--float-duration': icon.duration,
        '--float-delay': icon.delay,
      }"
      aria-hidden="true"
    >
      <img :src="icon.src" alt="" />
    </div>

    <section class="login-card">
      <header class="login-header">
        <div class="brand-icon">
          <img :src="bagIcon" alt="" />
        </div>
        <h1>
          Create
          <span>tradeX</span>
        </h1>
        <p class="subtitle">Join and start your shopping journey</p>
      </header>

      <form class="login-form" @submit.prevent="onSubmit">
        <label class="field" for="register-username">
          <span>Username</span>
          <div class="input-wrap">
            <img :src="mailIcon" alt="" />
            <input
              id="register-username"
              v-model="form.username"
              type="text"
              name="username"
              autocomplete="username"
              placeholder="Enter username"
              required
            />
          </div>
        </label>

        <label class="field" for="register-real-name">
          <span>Real Name</span>
          <div class="input-wrap">
            <img :src="mailIcon" alt="" />
            <input
              id="register-real-name"
              v-model="form.realName"
              type="text"
              name="real-name"
              placeholder="Enter real name"
              required
            />
          </div>
        </label>

        <label class="field" for="register-id-card">
          <span>ID Card</span>
          <div class="input-wrap">
            <img :src="mailIcon" alt="" />
            <input
              id="register-id-card"
              v-model="form.idCard"
              type="text"
              name="id-card"
              maxlength="18"
              placeholder="18-digit id card"
              required
            />
          </div>
        </label>

        <label class="field" for="register-phone">
          <span>Phone</span>
          <div class="input-wrap">
            <img :src="mailIcon" alt="" />
            <input
              id="register-phone"
              v-model="form.phone"
              type="tel"
              name="phone"
              placeholder="Enter phone number"
              required
            />
          </div>
        </label>

        <label class="field" for="register-address">
          <span>Address</span>
          <div class="input-wrap">
            <img :src="mailIcon" alt="" />
            <input
              id="register-address"
              v-model="form.address"
              type="text"
              name="address"
              placeholder="Enter shipping address"
              required
            />
          </div>
        </label>

        <label class="field" for="register-password">
          <span>Password</span>
          <div class="input-wrap">
            <img :src="lockIcon" alt="" />
            <input
              id="register-password"
              v-model="form.password"
              type="password"
              name="password"
              autocomplete="new-password"
              placeholder="Create a password"
              required
            />
            <button type="button" class="eye-btn" aria-label="toggle password visibility">
              <img :src="eyeIcon" alt="" />
            </button>
          </div>
        </label>

        <label class="field" for="register-confirm-password">
          <span>Confirm Password</span>
          <div class="input-wrap">
            <img :src="lockIcon" alt="" />
            <input
              id="register-confirm-password"
              v-model="form.confirmPassword"
              type="password"
              name="confirm-password"
              autocomplete="new-password"
              placeholder="Confirm your password"
              required
            />
            <button type="button" class="eye-btn" aria-label="toggle password visibility">
              <img :src="eyeIcon" alt="" />
            </button>
          </div>
        </label>

        <button type="submit" class="submit-btn" :disabled="form.loading">
          {{ form.loading ? 'Creating Account...' : 'Create Account' }}
        </button>

        <p v-if="form.error" class="status error">{{ form.error }}</p>
        <p v-if="form.success" class="status success">{{ form.success }}</p>
      </form>

      <footer class="login-footer">
        <span>Already have an account?</span>
        <RouterLink to="/login" class="link">Back to sign in</RouterLink>
      </footer>
    </section>
  </div>
</template>

<style scoped>
.login-page {
  --bg: #f4f3fa;
  --card-bg: #f7f7fa;
  --card-border: rgba(29, 34, 55, 0.08);
  --text-main: #11131f;
  --text-sub: #475569;
  --accent: #d4a373;
  --accent-2: #8b2f4a;
  --btn: #020226;

  min-height: 100vh;
  display: grid;
  place-items: center;
  position: relative;
  overflow: hidden;
  isolation: isolate;
  padding: 26px;
  background: linear-gradient(180deg, #f2f1f8 0%, #f7f6fc 100%);
  font-family: 'Microsoft YaHei', 'PingFang SC', sans-serif;
}

.bg-dots {
  position: absolute;
  inset: 0;
  z-index: -2;
  opacity: 0.4;
  background-image: radial-gradient(circle, rgba(153, 158, 184, 0.42) 1px, transparent 1px);
  background-size: 13px 13px;
}

.floating-icon {
  position: absolute;
  z-index: -1;
  opacity: 0.9;
  will-change: transform;
  animation: floatDrift var(--float-duration) ease-in-out infinite;
  animation-delay: var(--float-delay);
}

.floating-icon:nth-of-type(even) {
  animation-direction: reverse;
}

.floating-icon img {
  width: 100%;
  display: block;
  filter: drop-shadow(0 6px 11px rgba(61, 70, 102, 0.1));
  animation: iconSwing calc(var(--float-duration) * 0.7) ease-in-out infinite alternate;
}

.login-card {
  width: min(100%, 430px);
  border-radius: 20px;
  border: 1px solid var(--card-border);
  background: var(--card-bg);
  box-shadow: 0 20px 40px rgba(16, 24, 40, 0.1);
  padding: 30px 30px 26px;
  position: relative;
  z-index: 1;
  animation: reveal 0.6s ease-out;
}

.login-header {
  text-align: center;
  margin-bottom: 24px;
}

.login-header h1 {
  margin: 0 0 8px;
  color: var(--text-main);
  font-size: 47px;
  font-weight: 800;
  line-height: 1.1;
  letter-spacing: -0.04em;
}

.login-header h1 span {
  margin-left: 7px;
  background: linear-gradient(90deg, var(--accent) 0%, var(--accent-2) 100%);
  -webkit-background-clip: text;
  background-clip: text;
  color: transparent;
}

.brand-icon {
  width: 68px;
  height: 68px;
  margin: 0 auto 16px;
  border-radius: 18px;
  display: grid;
  place-items: center;
  background: linear-gradient(150deg, #d0661a 0%, #e09018 100%);
  box-shadow: 0 12px 24px rgba(80, 74, 200, 0.34);
}

.brand-icon img {
  width: 31px;
  filter: brightness(0) invert(1);
}

.subtitle {
  margin: 0;
  font-size: 16px;
  letter-spacing: -0.02em;
  font-weight: 600;
  color: var(--text-sub);
}

.login-form {
  display: grid;
  gap: 16px;
}

.field {
  display: grid;
  gap: 8px;
}

.field span {
  font-size: 14px;
  font-weight: 700;
  color: #202124;
}

.input-wrap {
  height: 50px;
  border-radius: 12px;
  background: #ececf0;
  border: 1px solid transparent;
  display: flex;
  align-items: center;
  padding: 0 13px;
  transition: border-color 0.2s ease, box-shadow 0.2s ease;
}

.input-wrap:focus-within {
  border-color: rgba(84, 98, 186, 0.45);
  box-shadow: 0 0 0 3px rgba(84, 98, 186, 0.12);
}

.input-wrap > img {
  width: 22px;
  flex-shrink: 0;
}

.input-wrap input {
  flex: 1;
  width: 100%;
  border: 0;
  background: transparent;
  font-size: 16px;
  font-weight: 500;
  color: #464c5f;
  padding: 0 11px;
}

.input-wrap input::placeholder {
  color: #757c8f;
}

.input-wrap input:focus {
  outline: none;
}

.eye-btn {
  border: 0;
  background: transparent;
  width: 28px;
  height: 28px;
  padding: 0;
  cursor: pointer;
  opacity: 0.9;
}

.eye-btn img {
  width: 22px;
}

.row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  font-size: 14px;
  margin-top: 1px;
}

.remember {
  display: inline-flex;
  align-items: center;
  gap: 8px;
  color: #1f2437;
  font-weight: 600;
}

.remember input {
  width: 20px;
  height: 20px;
  border-radius: 6px;
  accent-color: #6570c7;
}

.link {
  color: #1f56ef;
  font-weight: 700;
  text-decoration: none;
}

.link:hover {
  text-decoration: underline;
}

.submit-btn {
  margin-top: 6px;
  border: 0;
  border-radius: 12px;
  height: 50px;
  font-weight: 700;
  font-size: 16px;
  letter-spacing: 0.02em;
  color: white;
  cursor: pointer;
  background: var(--btn);
  box-shadow: 0 12px 20px rgba(1, 1, 24, 0.24);
  transition: transform 0.16s ease, box-shadow 0.16s ease;
}

.submit-btn:disabled {
  opacity: 0.7;
  cursor: not-allowed;
}

.submit-btn:hover {
  transform: translateY(-2px);
  box-shadow: 0 16px 26px rgba(1, 1, 24, 0.28);
}

.submit-btn:active {
  transform: translateY(0);
}

.login-footer {
  margin-top: 24px;
  font-size: 14px;
  font-weight: 600;
  color: var(--text-sub);
  display: flex;
  justify-content: center;
  gap: 8px;
}

.status {
  margin: 4px 2px 0;
  font-size: 13px;
  font-weight: 600;
}

.status.error {
  color: #b42318;
}

.status.success {
  color: #0d7a33;
}

@keyframes reveal {
  from {
    opacity: 0;
    transform: translateY(14px) scale(0.98);
  }
  to {
    opacity: 1;
    transform: translateY(0) scale(1);
  }
}

@keyframes floatDrift {
  0% {
    transform: translate3d(0, 0, 0);
  }
  25% {
    transform: translate3d(10px, -14px, 0);
  }
  50% {
    transform: translate3d(-12px, -24px, 0);
  }
  75% {
    transform: translate3d(12px, -10px, 0);
  }
  100% {
    transform: translate3d(0, 0, 0);
  }
}

@keyframes iconSwing {
  0% {
    transform: rotate(-4deg) scale(1);
  }
  100% {
    transform: rotate(4deg) scale(1.05);
  }
}

@media (max-width: 480px) {
  .login-page {
    padding: 14px;
  }

  .login-card {
    padding: 22px 18px 18px;
    border-radius: 18px;
  }

  .login-header h1 {
    font-size: 33px;
  }

  .subtitle {
    font-size: 15px;
  }

  .input-wrap input,
  .submit-btn {
    font-size: 15px;
  }

  .floating-icon {
    opacity: 0.58;
  }
}
</style>
