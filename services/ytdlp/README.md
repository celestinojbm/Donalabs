# yt-dlp — on-demand media download & extraction utility for DonaLabs

## 1. Overview

yt-dlp is a **command-line media utility**, not a long-running server or daemon. It provides safe, reproducible video downloads, audio extraction, subtitles, thumbnails, metadata, and playlist handling for any DonaLabs project that needs to pull media from a URL. DonaLabs ships it as a **pinned custom image** plus a **safe wrapper** (`services/ytdlp/ytdlp.sh`) that exposes a fixed set of curated subcommands. The compose service is **build-only** and guarded by the `tools` profile, so `docker compose up` never starts it — you invoke it on demand and each run uses a throwaway `--rm` container.

## 2. Image & versions

| Image | Tag / version | Role |
|-------|---------------|------|
| `donalabs/ytdlp` | `2026.7.4` (`${YTDLP_VERSION}`) | Custom image built locally from the `Dockerfile` in this directory |
| `python:3.12-slim-bookworm` | base | Runtime base; `yt-dlp[default]==2026.7.4` installed via pip |
| `denoland/deno:bin-2.9.1` | `${YTDLP_DENO_VERSION}` | Deno binary copied in via multi-stage build (required by the YouTube extractor since yt-dlp 2025.11.12) |
| `ffmpeg` / `ffprobe` | apt (bookworm) | Merging video+audio, audio extraction, subtitle/format conversion |

The image is **built locally**, not pulled from a registry. `yt-dlp` is pinned as a **PyPI package version**, not a Docker tag.

## 3. Quick start

This is a CLI, so "start" means "run a subcommand" — there is no service to keep running and nothing to `stop` (containers are `--rm` throwaways). The shared `donalabs_edge` network is auto-created by `start.sh`, but this tool does not use it.

**Build the image** (first use, or after bumping a version):

```bash
# From the service directory (preferred):
./services/ytdlp/ytdlp.sh build

# ...or from the repo root via compose (tools profile required):
docker compose --profile tools build ytdlp
```

The wrapper also **auto-builds** the image on first run if it is missing, so you can usually skip the explicit build.

**Run** (examples — see §7):

```bash
./services/ytdlp/ytdlp.sh audio "https://www.youtube.com/watch?v=..."
```

**Update** (yt-dlp goes stale fast — bump regularly):

```bash
# 1. Edit .env:  YTDLP_VERSION=<newer>   (optionally YTDLP_DENO_VERSION=<newer>)
# 2. Rebuild:
./services/ytdlp/ytdlp.sh build
```

**Backup** — the only state is your output directory:

```bash
tar czf ytdlp-downloads-$(date +%F).tar.gz -C services/ytdlp downloads
```

## 4. Configuration

The first three variables live in `.env` (from `.env.example`); the rest are optional wrapper-level environment variables read by `ytdlp.sh`.

| Variable | Purpose | Default / How-to |
|----------|---------|------------------|
| `YTDLP_VERSION` | yt-dlp PyPI package version — baked into the image as a build arg **and** used as the image tag (`donalabs/ytdlp:<ver>`) | `2026.7.4` |
| `YTDLP_DENO_VERSION` | Deno runtime version pulled via multi-stage `COPY` (required by the YouTube extractor) | `2.9.1` |
| `YTDLP_DOWNLOAD_DIR` | Host directory where downloaded media is written; mounted into the container at `/downloads` | `./services/ytdlp/downloads` |
| `YTDLP_SUBLANGS` | Subtitle languages for the `subs` subcommand (wrapper-only) | `en.*` |
| `YTDLP_COOKIES` | Optional path to a `cookies.txt`; mounted **read-only** at `/config/cookies.txt` for age/login-gated media (wrapper-only) | unset (disabled) |
| `TZ` | Timezone passed into the throwaway container | `UTC` (global `.env` default) |

Only `YTDLP_VERSION`, `YTDLP_DENO_VERSION`, and `YTDLP_DOWNLOAD_DIR` appear in `.env.example`. `YTDLP_SUBLANGS` and `YTDLP_COOKIES` are set ad-hoc in the shell when needed.

## 5. Access & first-run

**There is no URL and no port** — this is a CLI, not a web app. "Access" means running the wrapper.

First-run steps:

1. Ensure `.env` exists (`cp .env.example .env`) so `YTDLP_VERSION` and friends are defined.
2. Build the image once:
   ```bash
   ./services/ytdlp/ytdlp.sh build
   ```
3. Smoke-test that all three runtimes are present:
   ```bash
   docker run --rm --entrypoint sh donalabs/ytdlp:2026.7.4 \
     -c 'yt-dlp --version && ffmpeg -version | head -1 && deno --version'
   ```
4. Run your first download — output lands in `services/ytdlp/downloads/`.

## 6. Consume from other projects

**By design, yt-dlp exposes no network port and no API, and does not join the `donalabs_edge` network.** There is nothing to reach at a `service:port` — do not look for an internal hostname. Other projects and scripts consume it in one of two ways:

**(a) Call the safe wrapper** (recommended — validated, non-root, no arbitrary flags):

```bash
# From anywhere in the repo:
./services/ytdlp/ytdlp.sh audio "https://www.youtube.com/watch?v=dQw4w9WgXcQ"
./services/ytdlp/ytdlp.sh meta  "https://www.youtube.com/watch?v=dQw4w9WgXcQ" | jq .title
```

**(b) Run the image directly** (advanced — full yt-dlp CLI, no wrapper guardrails):

```bash
# Mount the current directory as the output target; pass raw yt-dlp args:
docker run --rm -v "$PWD:/downloads" donalabs/ytdlp:2026.7.4 --version
docker run --rm -v "$PWD:/downloads" donalabs/ytdlp:2026.7.4 -x --audio-format mp3 "<url>"
```

The image `ENTRYPOINT` is `yt-dlp`, so anything after the image name is passed straight to yt-dlp. Prefer path (a) unless you specifically need a flag the wrapper does not expose — path (b) can reach `--exec` and other RCE-adjacent options.

## 7. Usage examples

```bash
# Download best video+audio, merged to mp4:
./services/ytdlp/ytdlp.sh video "https://www.youtube.com/watch?v=dQw4w9WgXcQ"

# Extract audio to mp3 (best quality):
./services/ytdlp/ytdlp.sh audio "https://www.youtube.com/watch?v=dQw4w9WgXcQ"

# Download English subtitles as .srt (uses YTDLP_SUBLANGS):
./services/ytdlp/ytdlp.sh subs "https://www.youtube.com/watch?v=dQw4w9WgXcQ"

# Print metadata as JSON and pull one field with jq:
./services/ytdlp/ytdlp.sh meta "https://www.youtube.com/watch?v=dQw4w9WgXcQ" | jq -r '.title, .duration'

# Download a whole playlist into a per-playlist folder:
./services/ytdlp/ytdlp.sh playlist "https://www.youtube.com/playlist?list=PL..."
```

Other subcommands: `thumb` (thumbnail only), `formats` (list available formats, read-only), `version`, `build`. Run `./services/ytdlp/ytdlp.sh help` for the full list.

## 8. Security considerations

- **No arbitrary flag pass-through in the wrapper.** `ytdlp.sh` exposes only fixed subcommands with curated flags. This deliberately blocks `yt-dlp --exec`, which would be remote code execution.
- **`--ignore-config` on every run.** User/project yt-dlp config files are never read, so a config-injected `--exec` (or any other option) cannot take effect.
- **URLs are validated and never shell-interpolated.** Only `http://` / `https://` URLs are accepted; `file://` and option-injection (values starting with `-`) are rejected, and URLs are passed as argv after `--`.
- **Runs as non-root** (user `media`, uid 1000) inside the container.
- **Cookies mounted read-only.** `YTDLP_COOKIES`, if set, is bind-mounted `:ro` at `/config/cookies.txt`.
- **yt-dlp goes stale fast — bump `YTDLP_VERSION` regularly.** A version `>= 2026.07.04` is required to address **CVE-2026-55404**; older builds are vulnerable.
- The **direct `docker run` path (§6b) has none of the wrapper's guardrails** — only use it with trusted arguments.

## 9. Health check

This service has no HTTP endpoint, so it is intentionally **not** probed by `./scripts/health.sh` (that script only checks the port-bound web services). Health here means "the image's runtimes work":

- **Image `HEALTHCHECK`** runs `yt-dlp --version` (interval 1m, timeout 10s).
- **Manual smoke test** (verifies all three runtimes):

```bash
docker run --rm --entrypoint sh donalabs/ytdlp:2026.7.4 \
  -c 'yt-dlp --version && ffmpeg -version | head -1 && deno --version'
```

A quick liveness check via the wrapper:

```bash
./services/ytdlp/ytdlp.sh version
```

## 10. Troubleshooting

- **"image not found" on first run** — expected; the wrapper auto-builds it. If the build fails, run `./services/ytdlp/ytdlp.sh build` (or `docker compose --profile tools build ytdlp`) and read the build log.
- **`docker compose up` doesn't start yt-dlp** — correct and by design. It is build-only under the `tools` profile; use the wrapper or `docker compose --profile tools build ytdlp`.
- **YouTube extraction fails / "requires JS runtime"** — Deno must be present; rebuild the image so `YTDLP_DENO_VERSION` (2.9.1) is baked in, and verify with the §9 smoke test.
- **Extractor errors / HTTP 403 / signature failures** — yt-dlp is stale. Bump `YTDLP_VERSION` in `.env` and rebuild.
- **`refusing non-http(s) URL`** — the wrapper only accepts `http(s)` URLs; wrap the URL in quotes and drop any leading `-`.
- **Age/login-gated video needs auth** — export a `cookies.txt` and run with `YTDLP_COOKIES=/abs/path/cookies.txt ./services/ytdlp/ytdlp.sh ...`.
- **Downloads not appearing where expected** — files go to `YTDLP_DOWNLOAD_DIR` (default `services/ytdlp/downloads/`), mounted to `/downloads` in the container.
- **Permission errors on output** — the container runs as uid 1000; ensure your `YTDLP_DOWNLOAD_DIR` is writable by that uid (or by all).
