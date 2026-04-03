<template>
  <div class="message-page">
    <section class="message-card page-card">
      <div class="message-hero">
        <div class="message-icon">✉</div>
        <div>
          <p class="section-title">消息</p>
          <p class="section-subtitle">对应 mobile 端的消息占位页，当前仍然是开发中的状态。</p>
        </div>
      </div>

      <article class="notice-card">
        <div class="notice-top">
          <strong>系统通知</strong>
          <span>12:30</span>
        </div>
        <p>欢迎使用 tradeX！这里未来会接入订单、收藏、审核和 AI 导购通知。</p>
      </article>

      <article class="notice-card muted-card">
        <div class="notice-top">
          <strong>消息功能</strong>
          <span>开发中</span>
        </div>
        <p>目前仅保留与 mobile 一致的占位界面，用于后续接入实时会话和系统提醒。</p>
      </article>
    </section>
  </div>
</template>

<style scoped>
.message-page {
  display: grid;
  gap: 16px;
}

.message-card {
  padding: 18px;
  display: grid;
  gap: 14px;
}

.message-hero {
  display: flex;
  align-items: center;
  gap: 14px;
}

.message-icon {
  width: 72px;
  height: 72px;
  border-radius: 22px;
  display: grid;
  place-items: center;
  background: rgba(206, 150, 91, 0.12);
  color: var(--primary);
  font-size: 28px;
  font-weight: 900;
}

.notice-card {
  padding: 16px;
  border-radius: 18px;
  background: rgba(17, 19, 31, 0.04);
  display: grid;
  gap: 8px;
}

.notice-card p {
  color: var(--text-muted);
  line-height: 1.7;
}

.notice-top {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 10px;
}

.notice-top strong {
  font-size: 16px;
}

.notice-top span {
  font-size: 12px;
  color: var(--text-muted);
}

.muted-card {
  background: rgba(206, 150, 91, 0.08);
}
</style>
