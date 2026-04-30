<script setup>
import Hls from 'hls.js';
import { onBeforeUnmount, onMounted, ref } from 'vue';

const defaultPlaylist = 'http://localhost:8088/hls/test/index.m3u8';
const playlistUrl = ref(defaultPlaylist);
const videoRef = ref(null);
const status = ref('플레이리스트를 불러오는 중입니다...');

let hls = null;
let retryTimer = null;
let watchdogTimer = null;
let lastCurrentTime = 0;

function destroyPlayer() {
  if (retryTimer) {
    window.clearTimeout(retryTimer);
    retryTimer = null;
  }

  if (hls) {
    hls.off(Hls.Events.MANIFEST_PARSED);
    hls.off(Hls.Events.ERROR);
    hls.off(Hls.Events.BUFFER_EOS);
    hls.off(Hls.Events.FRAG_BUFFERED);
    hls.destroy();
    hls = null;
  }
  if (watchdogTimer) {
    window.clearInterval(watchdogTimer);
    watchdogTimer = null;
  }
}

function scheduleReload(message) {
  if (retryTimer) {
    return;
  }

  status.value = message;
  retryTimer = window.setTimeout(() => {
    retryTimer = null;
    loadStream();
  }, 2000);
}

function loadStream() {
  const video = videoRef.value;
  if (!video) return;

  destroyPlayer();

  if (Hls.isSupported()) {
    hls = new Hls({
      lowLatencyMode: true,
      liveSyncDurationCount: 2,
      liveMaxLatencyDurationCount: 4,
      maxBufferLength: 6,
      backBufferLength: 0,
      enableWorker: true
    });

    hls.loadSource(playlistUrl.value);
    hls.attachMedia(video);

    hls.on(Hls.Events.MANIFEST_PARSED, () => {
      status.value = '스트림 연결 성공. 재생을 시작합니다.';
      video.play().catch(() => {
        status.value = '자동 재생이 차단되었습니다. 재생 버튼을 눌러주세요.';
      });
    });

    hls.on(Hls.Events.ERROR, (_event, data) => {
      if (data.fatal) {
        if (data.type === Hls.ErrorTypes.NETWORK_ERROR) {
          scheduleReload(`네트워크 오류가 발생했습니다. 다시 연결하는 중입니다. (${data.details})`);
          return;
        }

        if (data.type === Hls.ErrorTypes.MEDIA_ERROR) {
          try {
            hls.recoverMediaError();
            hls.startLoad(-1);
          } catch (e) {}
          scheduleReload(`재생 상태를 복구하는 중입니다. (${data.details})`);
          return;
        }

        try { hls.startLoad(-1); } catch(e) {}
        scheduleReload(`재생 오류가 발생했습니다. 다시 연결하는 중입니다. (${data.details})`);
      }
    });

    // If the buffer signals end-of-stream (no newer segments), try reconnecting
    hls.on(Hls.Events.BUFFER_EOS, () => {
      try { hls.startLoad(-1); } catch(e) {}
      scheduleReload('스트림이 일시적으로 종료되었습니다. 다시 연결하는 중입니다.');
    });

    // FRAG_BUFFERED can be used to clear any pending reload timers
    hls.on(Hls.Events.FRAG_BUFFERED, () => {
      if (retryTimer) {
        window.clearTimeout(retryTimer);
        retryTimer = null;
        status.value = '스트림 버퍼 갱신감지 — 재생 유지 중입니다.';
      }
      // If video was paused/stalled, try to play
      try {
        const v = videoRef.value;
        if (v && v.paused) {
          v.play().catch(() => {});
        }
      } catch (e) {}
    });

    // Start a watchdog to detect stalls (currentTime not advancing)
    if (!watchdogTimer) {
      lastCurrentTime = video.currentTime || 0;
      watchdogTimer = window.setInterval(() => {
        try {
          const v = videoRef.value;
          if (!v) return;
          const now = v.currentTime || 0;
          // If playhead didn't move for >3s and not paused by user, try to jump to live
          if (!v.paused && Math.abs(now - lastCurrentTime) < 0.5) {
            if (hls) {
              try { hls.startLoad(-1); } catch (e) {}
            }
            v.play().catch(() => {});
          }
          lastCurrentTime = now;
        } catch (e) {}
      }, 3000);
    }

    video.addEventListener('ended', () => {
      scheduleReload('스트림이 끝났습니다. 다시 연결하는 중입니다.');
    }, { once: true });

    return;
  }

  if (video.canPlayType('application/vnd.apple.mpegurl')) {
    video.src = playlistUrl.value;
    video.addEventListener('loadedmetadata', () => {
      video.play().catch(() => {
        status.value = '자동 재생이 차단되었습니다. 재생 버튼을 눌러주세요.';
      });
    }, { once: true });
    video.addEventListener('ended', () => {
      scheduleReload('스트림이 끝났습니다. 다시 연결하는 중입니다.');
    }, { once: true });
    status.value = '네이티브 HLS로 재생 중입니다.';
    return;
  }

  status.value = '이 브라우저는 HLS 재생을 지원하지 않습니다.';
}

function applyPlaylist() {
  status.value = '플레이리스트를 다시 불러오는 중입니다...';
  loadStream();
}

onMounted(() => {
  loadStream();
});

onBeforeUnmount(() => {
  destroyPlayer();
});
</script>

<template>
  <main class="page">
    <section class="card">
      <header class="header">
        <h1 class="title">OBS → RTMP → HLS 실시간 시청</h1>
        <p class="subtitle">OBS에서 송출한 스트림을 브라우저에서 재생합니다.</p>
      </header>

      <div class="controls">
        <input
          v-model="playlistUrl"
          class="input"
          type="text"
          placeholder="http://localhost:8088/hls/test/index.m3u8"
        />
        <button class="button" @click="applyPlaylist">재생 주소 적용</button>
      </div>

      <div class="player-wrap">
        <video ref="videoRef" controls playsinline muted></video>
      </div>

      <p class="status">{{ status }}</p>
    </section>
  </main>
</template>
