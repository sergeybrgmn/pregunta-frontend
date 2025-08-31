<script setup>
import { ref, computed, watch } from 'vue'
import { useAuth, useClerk, useSession } from '@clerk/vue'
import { LANGUAGES } from '@/constants/languages.js'

// Props: provide selected episode details
const props = defineProps({
  // UUIDs come over JSON as strings
  episodeId: { type: String, default: null },
  audioUrl: { type: String, default: '' },
  disabled: { type: Boolean, default: false },
})

const audioEl = ref(null)
const recorder = ref(null)
const mediaStream = ref(null)
const chunks = ref([])
const isRecording = ref(false)
const answer = ref('')
const selectedLanguage = ref('en')
const modalMsg = ref('')

const { isSignedIn } = useAuth()
const { session } = useSession()
const { openSignUp } = useClerk()
const JWT_TEMPLATE = import.meta.env.VITE_CLERK_JWT_TEMPLATE

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
  // Require auth: open sign-up if not signed in
  if (!isSignedIn.value) {
    try {
      await openSignUp()
    } catch (e) {
      // Fall back to message if modal cannot open
      modalMsg.value = 'Please sign in to ask a question.'
    }
    return
  }
  // pause playback
  answer.value = ''
  try {
    audioEl.value?.pause()
  } catch (_) {}
  chunks.value = []

  if (typeof window.MediaRecorder === 'undefined') {
    modalMsg.value = 'Recording is not supported in this browser.'
    return
  }
  try {
    mediaStream.value = await navigator.mediaDevices.getUserMedia({ audio: true })
  } catch (e) {
    modalMsg.value = 'Microphone permission denied or unavailable.'
    return
  }
  try {
    // Prefer a widely-supported mimeType, with fallbacks
    let opts = {}
    const candidates = [
      'audio/webm;codecs=opus',
      'audio/webm',
      'audio/ogg;codecs=opus',
      'audio/mp4',
    ]
    for (const mt of candidates) {
      if (window.MediaRecorder.isTypeSupported?.(mt)) { opts = { mimeType: mt }; break }
    }
    recorder.value = new MediaRecorder(mediaStream.value, opts)
  } catch (e) {
    modalMsg.value = 'Could not start recorder.'
    return
  }
  recorder.value.ondataavailable = e => { if (e.data && e.data.size > 0) chunks.value.push(e.data) }
  recorder.value.onerror = () => { modalMsg.value = 'Recording error occurred.' }
  // Use a timeslice so we always have at least one chunk before stop
  recorder.value.start(750)
  isRecording.value = true
}

async function stopRecording() {
  if (!recorder.value) return
  recorder.value.onstop = async () => {
    if (!chunks.value.length) {
      modalMsg.value = 'No audio captured.'
      return
    }
    const blob = new Blob(chunks.value, { type: 'audio/webm' })
    const form = new FormData()
    // Backend expects episode_id now
    form.append('episode_id', String(props.episodeId ?? ''))
    form.append('timestamp', String(audioEl.value?.currentTime ?? 0))
    form.append('response_language', selectedLanguage.value)
    form.append('question_audio', blob, 'q.webm')

    // Auth token via Clerk Session (Vue: getToken is on session)
    let token = null
    try {
      token = await session.value?.getToken(JWT_TEMPLATE ? { template: JWT_TEMPLATE } : undefined)
    } catch (_) {
      token = null
    }

    const res = await fetch('/api/ask', {
      method: 'POST',
      body: form,
      headers: token ? { Authorization: `Bearer ${token}` } : undefined,
    })
    if (res.status === 401) {
      modalMsg.value = 'Unauthorized. Please sign in.'
      return
    }
    if (res.status === 403) {
      modalMsg.value = 'No questions left.'
      return
    }
    if (!res.ok) {
      modalMsg.value = `Request failed (${res.status}).`
      return
    }
    const json = await res.json()
    answer.value = json.answer

    // resume playback
    try {
      audioEl.value?.play()
    } catch (_) {}
  }
  try {
    recorder.value.stop()
  } catch (_) {}
  try {
    mediaStream.value?.getTracks()?.forEach(t => t.stop())
  } catch (_) {}
  isRecording.value = false
}
</script>

<template>
  <div class="player">
    <audio ref="audioEl" :src="audioUrl" controls />

    <div class="lang">
      <label for="response-language">Response language</label>
      <select id="response-language" v-model="selectedLanguage">
        <option v-for="l in LANGUAGES" :key="l.code" :value="l.code">{{ l.name }}</option>
      </select>
    </div>

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

    <div v-if="isRecording" class="rec-indicator">Recording… click Stop & Send to submit</div>

    <div v-if="answer" class="answer">
      <strong>Answer:</strong> {{ answer }}
    </div>

    <!-- Simple modal for errors -->
    <div v-if="modalMsg" class="modal">
      <div class="modal-card">
        <div class="modal-body">{{ modalMsg }}</div>
        <button class="ok-btn" @click="modalMsg = ''">OK</button>
      </div>
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
.lang { display: grid; gap: 0.25rem; }
.lang select { padding: 0.4rem; }
.answer {
  background: #f0f0f0;
  color: #000;       /* <-- make text black */
  padding: 0.75rem;
  border-radius: 4px;
}

.modal { position: fixed; inset: 0; background: rgba(0,0,0,0.4); display: grid; place-items: center; }
.modal-card { background: #fff; padding: 1rem; border-radius: 8px; min-width: 260px; max-width: 90vw; box-shadow: 0 4px 16px rgba(0,0,0,0.2); color: #111; }
.modal-body { margin-bottom: 0.75rem; color: #111; font-size: 1rem; }
.ok-btn { padding: 0.5rem 0.9rem; background: #3b82f6; color: #fff; border: 1px solid #3b82f6; border-radius: 6px; cursor: pointer; }
.ok-btn:hover { background: #2563eb; border-color: #2563eb; }
.ok-btn:focus { outline: 2px solid #93c5fd; outline-offset: 2px; }
</style>
