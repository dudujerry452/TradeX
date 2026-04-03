<script setup>
import { onMounted, reactive } from 'vue'
import { useRouter } from 'vue-router'
import { createProduct, getCategories } from '../config/api'
import { uploadImage } from '../services/imageUpload'
import { getUserId } from '../utils/auth'

const router = useRouter()

const form = reactive({
  name: '',
  price: '',
  stock: '',
  description: '',
  selectedCategory: '',
  uploadedImageUrl: '',
  categories: [],
  loadingCategories: false,
  uploadingImage: false,
  submitting: false,
  error: '',
  success: '',
})

const loadCategories = async () => {
  form.loadingCategories = true
  try {
    const result = await getCategories()
    if (result.success) {
      form.categories = (Array.isArray(result.data) ? result.data : []).filter(
        (item) => item.id !== 'all',
      )
      if (!form.selectedCategory && form.categories.length) {
        form.selectedCategory = form.categories[0].id
      }
    } else {
      form.error = result.message || '获取分类失败'
    }
  } finally {
    form.loadingCategories = false
  }
}

const pickImage = async () => {
  if (form.uploadingImage) return

  form.uploadingImage = true
  form.error = ''

  try {
    const result = await uploadImage()
    if (result.success) {
      form.uploadedImageUrl = result.url
    } else {
      form.error = result.message || '上传失败'
    }
  } finally {
    form.uploadingImage = false
  }
}

const resetForm = () => {
  form.name = ''
  form.price = ''
  form.stock = ''
  form.description = ''
  form.uploadedImageUrl = ''
  form.error = ''
  form.success = ''
}

const submitForm = async () => {
  if (form.submitting) return

  form.error = ''
  form.success = ''

  if (!form.name.trim()) {
    form.error = '请输入商品名称'
    return
  }
  if (!form.selectedCategory) {
    form.error = '请选择商品分类'
    return
  }
  if (!form.price || Number.isNaN(Number(form.price)) || Number(form.price) <= 0) {
    form.error = '请输入有效的价格'
    return
  }
  if (!form.stock || Number.isNaN(Number(form.stock)) || Number(form.stock) < 0) {
    form.error = '请输入有效的库存数量'
    return
  }
  if (!form.description.trim()) {
    form.error = '请输入商品描述'
    return
  }
  if (!form.uploadedImageUrl) {
    form.error = '请先上传商品图片'
    return
  }

  const userId = await getUserId()
  if (!userId) {
    form.error = '请先登录'
    return
  }

  form.submitting = true
  try {
    const result = await createProduct({
      product_name: form.name.trim(),
      description: form.description.trim(),
      price: Number(form.price),
      stock: Number(form.stock),
      category: form.selectedCategory,
      publisher_id: userId,
      image_url: form.uploadedImageUrl,
    })

    if (result.success) {
      form.success = '商品发布成功'
      resetForm()
      await loadCategories()
    } else {
      form.error = result.message || '发布失败'
    }
  } finally {
    form.submitting = false
  }
}

onMounted(() => {
  loadCategories()
})
</script>

<template>
  <div class="create-page">
    <section class="create-card page-card">
      <div class="create-head">
        <div>
          <p class="section-title">发布商品</p>
          <p class="section-subtitle">对应 mobile 端的“发布”页，占位图上传、分类和商品信息都已对齐。</p>
        </div>
        <button type="button" class="ghost-btn" @click="router.push('/home')">返回发现页</button>
      </div>

      <article v-if="form.error" class="status-card status-error">{{ form.error }}</article>
      <article v-if="form.success" class="status-card">{{ form.success }}</article>

      <div class="image-box input-shell" @click="pickImage">
        <div v-if="form.uploadingImage" class="image-state">上传中...</div>
        <img v-else-if="form.uploadedImageUrl" :src="form.uploadedImageUrl" alt="商品图片预览" />
        <div v-else class="image-state">
          <strong>点击选择本地图片</strong>
          <span>选择后会直接上传到后端 COS 服务</span>
        </div>
      </div>

      <form class="form-grid" @submit.prevent="submitForm">
        <label class="field">
          <span>商品名称</span>
          <input v-model="form.name" type="text" placeholder="请输入商品名称" />
        </label>

        <label class="field">
          <span>商品分类</span>
          <select v-model="form.selectedCategory" :disabled="form.loadingCategories">
            <option value="" disabled>请选择分类</option>
            <option v-for="category in form.categories" :key="category.id" :value="category.id">
              {{ category.name }}
            </option>
          </select>
        </label>

        <div class="field-row">
          <label class="field">
            <span>价格</span>
            <input v-model="form.price" type="number" min="0" step="0.01" placeholder="0.00" />
          </label>
          <label class="field">
            <span>库存</span>
            <input v-model="form.stock" type="number" min="0" step="1" placeholder="0" />
          </label>
        </div>

        <label class="field">
          <span>商品描述</span>
          <textarea v-model="form.description" rows="5" placeholder="请输入商品描述，介绍特点、规格、适用场景等" />
        </label>

        <button type="submit" class="primary-btn submit-btn" :disabled="form.submitting || form.loadingCategories">
          {{ form.submitting ? '发布中...' : '发布商品' }}
        </button>
      </form>
    </section>
  </div>
</template>

<style scoped>
.create-page {
  display: grid;
  gap: 16px;
}

.create-card {
  padding: 18px;
  display: grid;
  gap: 16px;
}

.create-head {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 14px;
}

.image-box {
  height: 220px;
  max-height: 220px;
  border-radius: 18px;
  overflow: hidden;
  display: flex;
  align-items: center;
  justify-content: center;
  background: linear-gradient(135deg, rgba(206, 150, 91, 0.08), rgba(17, 19, 31, 0.04));
  cursor: pointer;
  padding: 14px;
}

.image-box img {
  max-width: 100%;
  max-height: 100%;
  width: auto;
  height: auto;
  object-fit: contain;
  background: rgba(255, 255, 255, 0.88);
  border-radius: 14px;
}

.image-state {
  display: grid;
  gap: 6px;
  text-align: center;
  color: var(--text-muted);
  padding: 0 16px;
}

.image-state strong {
  color: #11131f;
  font-size: 18px;
}

.form-grid {
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

.field input,
.field textarea,
.field select {
  width: 100%;
  border: 1px solid rgba(17, 19, 31, 0.08);
  border-radius: 14px;
  background: rgba(255, 255, 255, 0.92);
  padding: 14px 16px;
  outline: none;
  color: var(--text);
}

.field textarea {
  resize: vertical;
  min-height: 140px;
}

.field-row {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 12px;
}

.submit-btn {
  min-height: 52px;
}

@media (max-width: 720px) {
  .create-card {
    padding: 14px;
  }

  .create-head {
    flex-direction: column;
  }

  .field-row {
    grid-template-columns: 1fr;
  }
}
</style>
