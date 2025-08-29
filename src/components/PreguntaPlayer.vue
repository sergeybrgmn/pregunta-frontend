<script setup>
import { ref, computed, watch } from 'vue'

// Props: provide selected episode details
const props = defineProps({
  // UUIDs come over JSON as strings
  episodeId: { type: String, default: null },
  audioUrl: { type: String, default: '' },
  disabled: { type: Boolean, default: false },
})

const audioEl = ref(null)
const recorder = ref(null)
const chunks = ref([])
const isRecording = ref(false)
const answer = ref('')

const canAsk = computed(() => !!props.episodeId && !props.disabled)

function resetAnswer() {
  answer.value = ''
}

// When episode changes, reset the shown answer
watch(() => props.episodeId, () => {
  resetAnswer()
})

async function startRecording() {
  if (!canAsk.value) return
  // pause playback
  answer.value = ''
  try {
    audioEl.value?.pause()
  } catch (_) {}
  chunks.value = []

  const stream = await navigator.mediaDevices.getUserMedia({ audio: true })
  recorder.value = new MediaRecorder(stream)
  recorder.value.ondataavailable = e => chunks.value.push(e.data)
  recorder.value.start()
  isRecording.value = true
}

async function stopRecording() {
  if (!recorder.value) return
  recorder.value.onstop = async () => {
    const blob = new Blob(chunks.value, { type: 'audio/webm' })
    const form = new FormData()
    // Backend expects episode_id now
    form.append('episode_id', String(props.episodeId ?? ''))
    form.append('timestamp', String(audioEl.value?.currentTime ?? 0))
    form.append('question_audio', blob, 'q.webm')

    const res = await fetch('/api/ask', {
      method: 'POST',
      body: form
    })
    const json = await res.json()
    answer.value = json.answer

    // resume playback
    try {
      audioEl.value?.play()
    } catch (_) {}
  }
  recorder.value.stop()
  isRecording.value = false
}
</script>

<template>
  <div class="player">
    <audio ref="audioEl" :src="audioUrl" controls />

    <!-- Start Recording: only enabled when not recording -->
    <button
      :disabled="isRecording || !canAsk"
      @click="startRecording"
      class="ask-btn"
    >
      ❓ Ask
    </button>

    <!-- Stop & Send: only enabled when recording -->
    <button
      :disabled="!isRecording"
      @click="stopRecording"
      class="ask-btn"
    >
      🛑 Stop & Send
    </button>

    <div v-if="answer" class="answer">
      <strong>Answer:</strong> {{ answer }}
    </div>
  </div>
</template>

<style scoped>
.player {
  display: flex;
  flex-direction: column;
  gap: 1rem;
  max-width: 400px;
  margin: auto;
}
.ask-btn {
  padding: 0.5rem 1rem;
  font-size: 1rem;
}
.answer {
  background: #f0f0f0;
  color: #000;       /* <-- make text black */
  padding: 0.75rem;
  border-radius: 4px;
}
</style>
