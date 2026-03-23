<template>
  <NModal v-model:show="show" preset="card" title="导入音源脚本" :bordered="false"
    style="width: 420px; border-radius: 16px;" :mask-closable="true">
    <div class="import-body">
      <label class="import-label">远程链接</label>
      <div class="import-row">
        <NInput v-model:value="urlInput" placeholder="https://example.com/source.js?key=xxx"
          :disabled="loading" @keydown.enter="handleUrl" />
        <NButton type="primary" :loading="loading" @click="handleUrl">下载</NButton>
      </div>
      <NDivider>或者</NDivider>
      <NButton block @click="handleFile" :disabled="loading">
        <template #icon>
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="16" height="16">
            <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/>
            <polyline points="14 2 14 8 20 8"/>
          </svg>
        </template>
        选择本地 .js 文件
      </NButton>
    </div>
  </NModal>
</template>

<script setup>
import { ref } from 'vue';
import { NModal, NInput, NButton, NDivider, useMessage } from 'naive-ui';

import { invoke } from '@tauri-apps/api/core';

const show = defineModel('show', { default: false });
const emit = defineEmits(['loaded']);

const urlInput = ref('');
const loading = ref(false);
const message = useMessage();

async function handleUrl() {
  const url = urlInput.value.trim();
  if (!url) return;
  loading.value = true;
  try {
    // 通过 Rust 端下载，绕过 CORS
    const content = await invoke('fetch_text', { url });
    emit('loaded', content);
    show.value = false;
    message.success('脚本下载成功');
  } catch (err) {
    message.error(`下载失败: ${err}`);
  } finally {
    loading.value = false;
  }
}

function handleFile() {
  const input = document.createElement('input');
  input.type = 'file';
  input.accept = '.js';
  input.onchange = async (e) => {
    const file = e.target.files[0];
    if (!file) return;
    const content = await file.text();
    emit('loaded', content);
    show.value = false;
    message.success('脚本加载成功');
  };
  input.click();
}
</script>

<style scoped>
.import-body { padding: 4px 0; }
.import-label {
  display: block; font-size: 12px; color: var(--text-color-secondary);
  margin-bottom: 8px; font-weight: 500;
}
.import-row { display: flex; gap: 8px; }
</style>
