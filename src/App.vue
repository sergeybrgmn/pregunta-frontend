<script setup>
import { ref, onMounted } from 'vue'
import PreguntaPlayer from './components/PreguntaPlayer.vue'
import { SignedIn, SignedOut, SignInButton, UserButton } from '@clerk/vue'

const podcasts = ref([])
const episodes = ref([])
const loadingPodcasts = ref(false)
const loadingEpisodes = ref(false)
const selectedPodcastId = ref(null)
const selectedEpisode = ref(null)
const errorMsg = ref('')

async function fetchPodcasts() {
  loadingPodcasts.value = true
  errorMsg.value = ''
  try {
    const res = await fetch('/api/podcasts')
    if (!res.ok) throw new Error(`Failed to load podcasts: ${res.status}`)
    podcasts.value = await res.json()
  } catch (e) {
    errorMsg.value = e?.message || 'Failed to load podcasts'
  } finally {
    loadingPodcasts.value = false
  }
}

async function fetchEpisodes(podcastId) {
  if (!podcastId) return
  loadingEpisodes.value = true
  errorMsg.value = ''
  try {
    const res = await fetch(`/api/podcast/${podcastId}/episodes`)
    if (!res.ok) throw new Error(`Failed to load episodes: ${res.status}`)
    episodes.value = await res.json()
  } catch (e) {
    errorMsg.value = e?.message || 'Failed to load episodes'
  } finally {
    loadingEpisodes.value = false
  }
}

function selectPodcast(podcast) {
  selectedPodcastId.value = podcast.id
  selectedEpisode.value = null
  episodes.value = []
  fetchEpisodes(podcast.id)
}

function selectEpisode(episode) {
  selectedEpisode.value = episode
}

onMounted(() => {
  fetchPodcasts()
})
</script>

<template>
  <div class="container">
    <header class="auth-header">
      <SignedOut>
        <SignInButton />
      </SignedOut>
      <SignedIn>
        <UserButton />
      </SignedIn>
    </header>
    <h1>Podcasts</h1>
    <div v-if="errorMsg" class="error">{{ errorMsg }}</div>
    <div class="podcasts" :class="{ loading: loadingPodcasts }">
      <div
        v-for="p in podcasts"
        :key="p.id"
        class="podcast-card"
        :class="{ selected: p.id === selectedPodcastId }"
        @click="selectPodcast(p)"
        role="button"
        tabindex="0"
      >
        <div class="cover">
          <img v-if="p.cover_url" :src="p.cover_url" :alt="p.title" />
          <div v-else class="cover-placeholder">No cover</div>
        </div>
        <div class="title" :title="p.title">{{ p.title }}</div>
      </div>
      <div v-if="!loadingPodcasts && podcasts.length === 0" class="empty">No podcasts</div>
    </div>

    <h2>Episodes</h2>
    <div class="episodes" :class="{ disabled: !selectedPodcastId }">
      <div v-if="!selectedPodcastId" class="hint">Select a podcast to see episodes</div>
      <div v-else-if="loadingEpisodes" class="hint">Loading episodes…</div>
      <button
        v-for="e in episodes"
        :key="e.id"
        class="episode"
        :class="{ selected: selectedEpisode && e.id === selectedEpisode.id }"
        @click="selectEpisode(e)"
      >
        {{ e.title }}
      </button>
      <div v-if="!loadingEpisodes && selectedPodcastId && episodes.length === 0" class="hint">No episodes</div>
    </div>

    <h2>Player</h2>
    <PreguntaPlayer
      :episode-id="selectedEpisode?.id || null"
      :audio-url="selectedEpisode?.audio_url || ''"
      :disabled="!selectedEpisode"
    />
  </div>
</template>

<style scoped>
.auth-header { display: flex; justify-content: flex-end; margin-bottom: 0.5rem; }
.container {
  display: grid;
  gap: 1rem;
  max-width: 900px;
  margin: 1rem auto;
  padding: 0 1rem;
}

h1, h2 {
  margin: 0.5rem 0;
}

.error {
  color: #b00020;
}

/* Podcasts: horizontal scroll feed */
.podcasts {
  display: flex;
  gap: 0.75rem;
  overflow-x: auto;
  padding-bottom: 0.25rem;
}
.podcast-card {
  flex: 0 0 auto;
  width: 140px;
  cursor: pointer;
  border: 1px solid #e2e2e2;
  border-radius: 8px;
  padding: 0.5rem;
  background: #fff;
  transition: box-shadow 0.15s ease, transform 0.1s ease;
}
.podcast-card:hover { box-shadow: 0 2px 8px rgba(0,0,0,0.1); transform: translateY(-1px); }
.podcast-card.selected { outline: 2px solid #3b82f6; }
.cover { width: 100%; aspect-ratio: 1; overflow: hidden; border-radius: 6px; background: #f5f5f5; display: grid; place-items: center; }
.cover img { width: 100%; height: 100%; object-fit: cover; display: block; }
.cover-placeholder { color: #888; font-size: 0.9rem; }
.title { margin-top: 0.5rem; font-size: 0.95rem; line-height: 1.2; display: -webkit-box; -webkit-line-clamp: 2; -webkit-box-orient: vertical; overflow: hidden; }
.empty { color: #666; }

/* Episodes: vertical selectable list */
.episodes { display: flex; flex-wrap: wrap; gap: 0.5rem; }
.episodes.disabled { opacity: 0.6; }
.episode { padding: 0.5rem 0.75rem; border-radius: 999px; border: 1px solid #e2e2e2; background: #fff; cursor: pointer; }
.episode.selected { background: #3b82f6; color: #fff; border-color: #3b82f6; }
.hint { color: #666; }
</style>
