# =============================================================================
# yt-dlp media utility image for DonaLabs.
# yt-dlp is a CLI (not a server). This image bundles the three runtimes it needs:
#   - Python + the pinned yt-dlp package
#   - ffmpeg/ffprobe  (merging video+audio, audio extraction, post-processing)
#   - Deno            (required for full YouTube support since yt-dlp 2025.11.12)
# =============================================================================

# Deno is provided as a pinned, prebuilt binary via multi-stage copy — this is
# reproducible and works behind proxies (no install script / network fetch).
ARG DENO_VERSION=2.9.1
FROM denoland/deno:bin-${DENO_VERSION} AS deno

FROM python:3.12-slim-bookworm

# Pin the yt-dlp PyPI package version (NOT a docker tag — yt-dlp ships as a package).
ARG YTDLP_VERSION=2026.7.4

# ffmpeg/ffprobe for media post-processing; CA certs for TLS.
RUN apt-get update \
 && apt-get install -y --no-install-recommends ffmpeg ca-certificates \
 && rm -rf /var/lib/apt/lists/*

# Deno binary (JS runtime required by the YouTube extractor).
COPY --from=deno /deno /usr/local/bin/deno

# Install the pinned yt-dlp with default extras.
RUN pip install --no-cache-dir "yt-dlp[default]==${YTDLP_VERSION}"

# Run as a non-root user; /downloads is the output directory.
RUN useradd -m -u 1000 media && mkdir -p /downloads /config && chown -R media:media /downloads /config
USER media
WORKDIR /downloads

# Fail the build if any runtime is missing.
RUN yt-dlp --version && ffmpeg -version >/dev/null && deno --version

ENTRYPOINT ["yt-dlp"]
CMD ["--version"]

HEALTHCHECK --interval=1m --timeout=10s CMD ["yt-dlp", "--version"]
