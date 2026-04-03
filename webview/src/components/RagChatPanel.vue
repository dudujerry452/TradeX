<script setup>
import { nextTick, reactive, ref } from 'vue'
import { RouterLink } from 'vue-router'
import { RAG_CHAT_STREAM_API_URL } from '../config/api'

const state = reactive({
  chatInput: '',
  chatSending: false,
  chatError: '',
  chatMessages: [
    {
      id: 'welcome',
      role: 'assistant',
      content: '你好，我是 tradeX 智能导购。告诉我预算、品类或使用场景，我会实时推荐商品。',
    },
  ],
  chatSources: [],
})

const chatViewportRef = ref(null)

const scrollChatToBottom = () => {
  nextTick(() => {
    const el = chatViewportRef.value
    if (el) {
      el.scrollTop = el.scrollHeight
    }
  })
}

const parseSseBlock = (block) => {
  let event = 'message'
  const dataLines = []
  for (const line of block.split('\n')) {
    if (line.startsWith('event:')) {
      event = line.slice(6).trim()
    } else if (line.startsWith('data:')) {
      dataLines.push(line.slice(5).trimStart())
    }
  }
  return { event, dataText: dataLines.join('\n') }
}

const appendAssistantContent = (assistantId, text) => {
  if (!text) return
  const msg = state.chatMessages.find((item) => item.id === assistantId)
  if (!msg) return
  msg.content += text
}

const getAssistantContent = (assistantId) => {
  const msg = state.chatMessages.find((item) => item.id === assistantId)
  return msg?.content || ''
}

const setAssistantContent = (assistantId, text) => {
  const msg = state.chatMessages.find((item) => item.id === assistantId)
  if (!msg) return
  msg.content = text
}

const applySsePayload = (assistantId, event, payload) => {
  if (event === 'meta') {
    state.chatSources = Array.isArray(payload.products) ? payload.products : []
    return
  }
  if (event === 'token' && payload.token) {
    appendAssistantContent(assistantId, payload.token)
    scrollChatToBottom()
    return
  }
  if (event === 'error') {
    throw new Error(payload.error || '流式生成失败')
  }
}

const consumeSseBuffer = (assistantId, rawBuffer, flushAll = false) => {
  const blocks = rawBuffer.split(/\r?\n\r?\n/)
  const remain = flushAll ? '' : (blocks.pop() || '')

  for (const block of blocks) {
    if (!block.trim()) continue

    const { event, dataText } = parseSseBlock(block)
    let payload = {}
    try {
      payload = dataText ? JSON.parse(dataText) : {}
    } catch {
      payload = {}
    }
    applySsePayload(assistantId, event, payload)
  }

  return remain
}

const sendRagMessage = async () => {
  const question = state.chatInput.trim()
  if (!question || state.chatSending) return

  state.chatInput = ''
  state.chatError = ''
  state.chatSending = true
  state.chatMessages.push({
    id: `user-${Date.now()}`,
    role: 'user',
    content: question,
  })
  const assistantId = `assistant-${Date.now()}`
  state.chatMessages.push({
    id: assistantId,
    role: 'assistant',
    content: '',
  })
  scrollChatToBottom()

  try {
    const response = await fetch(RAG_CHAT_STREAM_API_URL, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        question,
        n_results: 3,
      }),
    })

    if (!response.ok || !response.body) {
      let msg = `请求失败: ${response.status}`
      try {
        const err = await response.json()
        if (err?.detail) msg = err.detail
      } catch {
        // Keep fallback message.
      }
      throw new Error(msg)
    }

    const reader = response.body.getReader()
    const decoder = new TextDecoder('utf-8')
    let buffer = ''

    while (true) {
      const { value, done } = await reader.read()
      if (done) {
        buffer += decoder.decode()
        buffer = consumeSseBuffer(assistantId, buffer, true)
        break
      }

      buffer += decoder.decode(value, { stream: true })
      buffer = consumeSseBuffer(assistantId, buffer, false)
    }

    if (!getAssistantContent(assistantId).trim()) {
      setAssistantContent(assistantId, '未收到模型回复，请稍后再试。')
    }
  } catch (error) {
    state.chatError = error instanceof Error ? error.message : '发送消息失败'
    if (!getAssistantContent(assistantId).trim()) {
      setAssistantContent(assistantId, `抱歉，当前无法完成回答。${state.chatError}`)
    }
  } finally {
    state.chatSending = false
    scrollChatToBottom()
  }
}

const onChatEnter = (event) => {
  if (event.key === 'Enter' && !event.shiftKey) {
    event.preventDefault()
    sendRagMessage()
  }
}

const getSourceLink = (item) => {
  if (typeof item?.url === 'string' && item.url) {
    return item.url
  }

  if (typeof item?.id === 'string' && item.id) {
    return `/product/${item.id}`
  }

  return ''
}

const linkPattern = /\[([^\]]+)\]\((\/[^)]+)\)/g

const parseMessageSegments = (content) => {
  if (typeof content !== 'string' || !content) {
    return []
  }

  const segments = []
  let lastIndex = 0

  for (const match of content.matchAll(linkPattern)) {
    const [fullMatch, label, to] = match
    const index = match.index ?? 0

    if (index > lastIndex) {
      segments.push({ type: 'text', value: content.slice(lastIndex, index) })
    }

    segments.push({ type: 'link', label, to })
    lastIndex = index + fullMatch.length
  }

  if (lastIndex < content.length) {
    segments.push({ type: 'text', value: content.slice(lastIndex) })
  }

  return segments.length ? segments : [{ type: 'text', value: content }]
}
</script>

<template>
  <section class="chat-wrap">
    <header class="chat-topbar">
      <div class="brand-block">
        <div class="brand-dot" aria-hidden="true"></div>
        <div>
          <h2 class="chat-title">tradeX AI 导购</h2>
          <p class="chat-subtitle">流式推荐 · 基于商品知识库</p>
        </div>
      </div>
      <span class="chat-status-chip" :class="{ running: state.chatSending }">
        <span class="status-light" aria-hidden="true"></span>
        {{ state.chatSending ? '思考中' : '在线' }}
      </span>
    </header>

    <div class="chat-shell">
      <aside class="source-panel">
        <div class="source-head">命中商品</div>
        <p v-if="!state.chatSources.length" class="source-empty">提问后将展示当前命中的候选商品。</p>
        <ul v-else class="source-list">
          <li v-for="item in state.chatSources" :key="item.id || item.name">
            <RouterLink v-if="getSourceLink(item)" class="source-card source-link" :to="getSourceLink(item)">
              <div class="source-main">
                <strong>{{ item.name }}</strong>
                <small>{{ item.category }}</small>
              </div>
              <span class="source-price">¥{{ item.price }}</span>
            </RouterLink>
            <div v-else class="source-card">
              <div class="source-main">
                <strong>{{ item.name }}</strong>
                <small>{{ item.category }}</small>
              </div>
              <span class="source-price">¥{{ item.price }}</span>
            </div>
          </li>
        </ul>
      </aside>

      <div class="chat-main">
        <div ref="chatViewportRef" class="chat-viewport">
          <div
            v-for="msg in state.chatMessages"
            :key="msg.id"
            class="message-row"
            :class="msg.role === 'user' ? 'message-row-user' : 'message-row-assistant'"
          >
            <div class="avatar" :class="msg.role === 'user' ? 'avatar-user' : 'avatar-assistant'">
              {{ msg.role === 'user' ? 'U' : 'AI' }}
            </div>
            <div class="message-bubble" :class="msg.role === 'user' ? 'bubble-user' : 'bubble-assistant'">
              <p>
                <template v-for="(segment, index) in parseMessageSegments(msg.content)" :key="index">
                  <RouterLink v-if="segment.type === 'link'" class="message-link" :to="segment.to">
                    {{ segment.label }}
                  </RouterLink>
                  <span v-else>{{ segment.value }}</span>
                </template>
              </p>
            </div>
          </div>

          <div v-if="state.chatSending" class="typing-row">
            <span></span><span></span><span></span>
          </div>
        </div>

        <p v-if="state.chatError" class="chat-error">{{ state.chatError }}</p>

        <form class="composer" @submit.prevent="sendRagMessage">
          <textarea
            v-model="state.chatInput"
            class="composer-input"
            rows="2"
            placeholder="输入你的需求，例如：预算 800 内，通勤降噪，优先蓝牙耳机"
            @keydown="onChatEnter"
          ></textarea>
          <div class="composer-foot">
            <span class="composer-tip">Enter 发送 · Shift + Enter 换行</span>
            <button type="submit" class="send-btn" :disabled="state.chatSending || !state.chatInput.trim()">
              {{ state.chatSending ? '生成中…' : '发送消息' }}
            </button>
          </div>
        </form>
      </div>
    </div>
  </section>
</template>

<style scoped>
.chat-wrap {
  --bg-soft: #f7f8fa;
  --line: #d9dde3;
  --ink-1: #101418;
  --ink-2: #4b5563;
  --brand: #111827;
  --assistant: #eef4ff;
  --user: #111827;
  display: grid;
  gap: 16px;
}

.chat-topbar {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 10px;
}

.brand-block {
  display: flex;
  align-items: center;
  gap: 12px;
}

.brand-dot {
  width: 14px;
  height: 14px;
  border-radius: 999px;
  background: radial-gradient(circle at 35% 35%, #6ee7b7 0%, #047857 100%);
  box-shadow: 0 0 0 4px #d1fae5;
}

.chat-title {
  margin: 0;
  color: var(--ink-1);
  font-size: 28px;
  line-height: 1.1;
  font-weight: 800;
  letter-spacing: 0.01em;
}

.chat-subtitle {
  margin: 3px 0 0;
  color: var(--ink-2);
  font-size: 13px;
}

.chat-status-chip {
  display: inline-flex;
  align-items: center;
  gap: 8px;
  background: #e5e7eb;
  color: #111827;
  border-radius: 999px;
  padding: 6px 12px;
  font-size: 13px;
  font-weight: 700;
}

.status-light {
  width: 8px;
  height: 8px;
  border-radius: 50%;
  background: #16a34a;
}

.chat-status-chip.running .status-light {
  background: #0284c7;
  animation: pulse 1.1s ease-in-out infinite;
}

.chat-shell {
  display: grid;
  grid-template-columns: 280px 1fr;
  gap: 16px;
}

.source-panel {
  border: 1px solid var(--line);
  border-radius: 16px;
  background: linear-gradient(165deg, #ffffff 0%, #f8fbff 100%);
  padding: 14px;
  display: grid;
  align-content: start;
  gap: 12px;
  max-height: 540px;
  overflow: auto;
}

.source-head {
  font-size: 13px;
  letter-spacing: 0.08em;
  color: #6b7280;
  text-transform: uppercase;
  font-weight: 700;
}

.source-empty {
  margin: 0;
  font-size: 12px;
  line-height: 1.5;
  color: #6b7280;
}

.source-list {
  margin: 0;
  padding: 0;
  list-style: none;
  display: grid;
  gap: 10px;
}

.source-card {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 10px;
  border: 1px solid #e6ebf2;
  background: #fff;
  border-radius: 12px;
  padding: 10px;
}

.source-link {
  color: inherit;
  text-decoration: none;
  transition: transform 0.18s ease, box-shadow 0.18s ease, border-color 0.18s ease;
}

.source-link:hover {
  transform: translateY(-1px);
  border-color: #cfd8e3;
  box-shadow: 0 10px 20px rgba(16, 24, 40, 0.08);
}

.source-main {
  display: grid;
  gap: 3px;
}

.source-main strong {
  font-size: 13px;
  color: var(--ink-1);
}

.source-main small {
  font-size: 12px;
  color: #6b7280;
}

.source-price {
  font-weight: 800;
  font-size: 13px;
  color: #111827;
}

.chat-main {
  border: 1px solid var(--line);
  border-radius: 16px;
  background: #fff;
  padding: 12px;
  display: grid;
  gap: 12px;
}

.chat-viewport {
  min-height: 260px;
  max-height: 440px;
  overflow-y: auto;
  border-radius: 12px;
  border: 1px solid #e6ebf2;
  padding: 14px;
  background: var(--bg-soft);
  display: grid;
  gap: 10px;
}

.message-row {
  display: flex;
  align-items: flex-start;
  gap: 10px;
}

.message-row-user {
  justify-content: flex-end;
}

.message-row-user .avatar {
  order: 2;
}

.message-row-user .message-bubble {
  order: 1;
}

.avatar {
  width: 30px;
  height: 30px;
  border-radius: 10px;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  font-size: 11px;
  font-weight: 800;
  flex-shrink: 0;
}

.avatar-assistant {
  background: #dbeafe;
  color: #1d4ed8;
}

.avatar-user {
  background: #111827;
  color: #fff;
}

.message-bubble {
  max-width: min(80%, 760px);
  border-radius: 14px;
  padding: 10px 12px;
  font-size: 14px;
  line-height: 1.55;
  white-space: pre-wrap;
  box-shadow: 0 2px 6px rgba(17, 24, 39, 0.08);
}

.message-bubble p {
  margin: 0;
}

.message-link {
  color: #1d4ed8;
  font-weight: 700;
  text-decoration: underline;
  text-underline-offset: 2px;
}

.bubble-user .message-link {
  color: #93c5fd;
}

.bubble-assistant {
  background: var(--assistant);
  color: #12213f;
  border-top-left-radius: 6px;
}

.bubble-user {
  background: var(--user);
  color: #fff;
  border-top-right-radius: 6px;
}

.typing-row {
  display: inline-flex;
  gap: 6px;
  margin-left: 40px;
}

.typing-row span {
  width: 7px;
  height: 7px;
  border-radius: 999px;
  background: #94a3b8;
  animation: bounce 1s infinite;
}

.typing-row span:nth-child(2) {
  animation-delay: 0.14s;
}

.typing-row span:nth-child(3) {
  animation-delay: 0.28s;
}

.chat-error {
  margin: 0 4px;
  color: #b42318;
  font-size: 13px;
  font-weight: 600;
}

.composer {
  border: 1px solid #dbe1e8;
  border-radius: 14px;
  background: #fff;
  padding: 10px;
  display: grid;
  gap: 8px;
}

.composer-input {
  border: 0;
  outline: none;
  resize: none;
  min-height: 68px;
  max-height: 180px;
  font-size: 14px;
  line-height: 1.5;
  font-family: inherit;
  color: var(--ink-1);
  background: transparent;
}

.composer-foot {
  display: grid;
  grid-template-columns: 1fr auto;
  align-items: center;
  gap: 10px;
}

.composer-tip {
  color: #6b7280;
  font-size: 12px;
}

.send-btn {
  min-width: 110px;
  border: 0;
  border-radius: 11px;
  padding: 10px 14px;
  background: linear-gradient(120deg, #111827 0%, #1f2937 100%);
  color: #fff;
  font-size: 14px;
  font-weight: 700;
  cursor: pointer;
}

.send-btn:disabled {
  opacity: 0.6;
  cursor: not-allowed;
}

@keyframes pulse {
  0% {
    opacity: 0.45;
    transform: scale(0.85);
  }
  50% {
    opacity: 1;
    transform: scale(1);
  }
  100% {
    opacity: 0.45;
    transform: scale(0.85);
  }
}

@keyframes bounce {
  0%,
  80%,
  100% {
    transform: translateY(0);
    opacity: 0.5;
  }
  40% {
    transform: translateY(-4px);
    opacity: 1;
  }
}

@media (max-width: 900px) {
  .chat-title {
    font-size: 24px;
  }

  .chat-shell {
    grid-template-columns: 1fr;
  }

  .source-panel {
    max-height: none;
  }

  .chat-viewport {
    max-height: 300px;
  }

  .composer-foot {
    grid-template-columns: 1fr;
    justify-items: end;
  }

  .composer-tip {
    justify-self: start;
  }
}
</style>
