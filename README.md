# RTMP Video Streaming Stack (OBS + NGINX-RTMP + Vue)

이 프로젝트는 아래 흐름으로 동작합니다.

- 송출자: OBS에서 RTMP 서버로 라이브 송출
- 스트리밍 서버: NGINX-RTMP가 RTMP를 받아 HLS(.m3u8/.ts)로 변환
- 시청자: Vue.js 웹 페이지에서 HLS 재생

브라우저는 RTMP를 직접 재생하지 못하므로, 서버에서 HLS로 변환해서 재생합니다.

## 1) 구성 요소

- RTMP ingest: `rtmp://localhost:1935/live`
- Stream key 예시: `test`
- HLS playlist URL: `http://localhost:8088/hls/test/index.m3u8`
- Vue viewer dev server: `http://localhost:5273`

## 2) 서버 실행

### RTMP/HLS 서버 실행

```bash
docker compose up -d
```

확인:

```bash
docker compose ps
curl http://localhost:8088/
```

## 3) OBS 설정

- OBS > 설정 > 방송:

- 서비스: 사용자 정의(Custom)
- 서버: `rtmp://localhost:1935/live`
- 스트림 키: `test`

설정을 저장하고 방송 시작을 누르면 HLS 세그먼트가 생성됩니다.

지연을 더 줄이려면 OBS > 설정 > 출력에서 아래도 맞추세요.

- 키프레임 간격: 1초
- 프레임 레이트: 30fps 권장
- 비트레이트: 네트워크에 맞게 CBR 사용

## 4) Vue 시청 페이지 실행

```bash
cd viewer
npm install
npm run dev
```

브라우저에서 `http://localhost:5273` 접속 후 기본 주소(`http://localhost:8088/hls/test/index.m3u8`)로 재생하면 됩니다.

## 5) 폴더 구조

```text
.
├─ docker-compose.yml
├─ nginx/
│  └─ nginx.conf
└─ viewer/
	 ├─ index.html
	 ├─ package.json
	 ├─ vite.config.js
	 └─ src/
			├─ App.vue
			├─ main.js
			└─ assets/
				 └─ base.css
```

## 6) 트러블슈팅

- `404 /hls/test/index.m3u8`
	- OBS가 실제로 송출 중인지 확인
	- OBS 서버/스트림 키 값이 정확한지 확인
- 화면이 몇 초 늦게 보임
	- HLS 특성상 RTMP보다 지연이 있습니다.
	- 이 프로젝트는 세그먼트 시간을 줄여 지연을 낮춘 상태입니다.
	- 더 낮은 지연이 필요하면 WebRTC 구조로 바꿔야 합니다.
- 브라우저에서 재생 실패
	- `http://localhost:8088/hls/test/index.m3u8` URL이 브라우저에서 열리는지 확인
	- 회사/학교 네트워크에서 포트 `1935`, `8088` 차단 여부 확인
- 외부 접속으로 배포할 때
	- `localhost` 대신 서버 공인 IP 또는 도메인으로 변경
	- 방화벽/보안그룹에서 `1935`, `8088` 허용
