#!/usr/bin/env bash
# =============================================================================
# DonaLabs — safe yt-dlp wrapper
#
# A thin, SAFE front-end over the containerized yt-dlp. It exposes a fixed set of
# subcommands with curated flags. It deliberately does NOT:
#   * pass arbitrary flags through to yt-dlp (which could enable --exec = RCE),
#   * read user yt-dlp config files (runs with --ignore-config),
#   * build shell strings from user input (URLs are passed as argv after `--`).
#
# Usage:
#   ./ytdlp.sh video <url> [url...]      Download best video+audio (mp4)
#   ./ytdlp.sh audio <url> [url...]      Extract audio to mp3
#   ./ytdlp.sh subs  <url> [url...]      Download subtitles only (srt)
#   ./ytdlp.sh thumb <url> [url...]      Download thumbnail only
#   ./ytdlp.sh meta  <url>               Print metadata as JSON (stdout)
#   ./ytdlp.sh formats <url>             List available formats (read-only)
#   ./ytdlp.sh playlist <url>            Download a whole playlist (mp4)
#   ./ytdlp.sh version                   Print the yt-dlp version
#   ./ytdlp.sh build                     (Re)build the image
#
# Environment:
#   YTDLP_VERSION       Image/package version (default 2026.7.4)
#   YTDLP_DOWNLOAD_DIR  Output directory (default: ./downloads next to this script)
#   YTDLP_SUBLANGS      Subtitle languages for `subs` (default: en.*)
#   YTDLP_COOKIES       Path to a cookies.txt (optional; mounted read-only)
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
YTDLP_VERSION="${YTDLP_VERSION:-2026.7.4}"
DENO_VERSION="${YTDLP_DENO_VERSION:-2.9.1}"
IMAGE="donalabs/ytdlp:${YTDLP_VERSION}"
DOWNLOAD_DIR="${YTDLP_DOWNLOAD_DIR:-${SCRIPT_DIR}/downloads}"
SUBLANGS="${YTDLP_SUBLANGS:-en.*}"

die() { echo "ytdlp: $*" >&2; exit 2; }

# Only accept http(s) URLs. This also prevents a value beginning with '-' from
# being interpreted as a yt-dlp option.
validate_url() {
  case "$1" in
    https://*|http://*) : ;;
    *) die "refusing non-http(s) URL: '$1'";;
  esac
}

ensure_image() {
  if ! docker image inspect "$IMAGE" >/dev/null 2>&1; then
    echo "ytdlp: image $IMAGE not found — building..." >&2
    docker build --build-arg "YTDLP_VERSION=${YTDLP_VERSION}" --build-arg "DENO_VERSION=${DENO_VERSION}" -t "$IMAGE" "$SCRIPT_DIR" >&2
  fi
}

# run <yt-dlp args...> — executes yt-dlp in a throwaway container.
run() {
  mkdir -p "$DOWNLOAD_DIR"
  local -a mounts=(-v "${DOWNLOAD_DIR}:/downloads")
  if [ -n "${YTDLP_COOKIES:-}" ]; then
    [ -f "$YTDLP_COOKIES" ] || die "YTDLP_COOKIES file not found: $YTDLP_COOKIES"
    mounts+=(-v "$(cd "$(dirname "$YTDLP_COOKIES")" && pwd)/$(basename "$YTDLP_COOKIES"):/config/cookies.txt:ro")
  fi
  docker run --rm -i "${mounts[@]}" -e "TZ=${TZ:-UTC}" "$IMAGE" --ignore-config "$@"
}

# Assemble the cookies flag (if any) once.
cookies_flag() { [ -n "${YTDLP_COOKIES:-}" ] && printf -- '--cookies\n/config/cookies.txt\n'; }

cmd="${1:-}"; shift || true

case "$cmd" in
  video|download)
    [ "$#" -ge 1 ] || die "usage: ytdlp.sh video <url> [url...]"
    for u in "$@"; do validate_url "$u"; done
    ensure_image
    mapfile -t ck < <(cookies_flag)
    run -f "bv*+ba/b" --merge-output-format mp4 --no-playlist \
        -o "%(title)s [%(id)s].%(ext)s" "${ck[@]}" -- "$@"
    ;;
  audio)
    [ "$#" -ge 1 ] || die "usage: ytdlp.sh audio <url> [url...]"
    for u in "$@"; do validate_url "$u"; done
    ensure_image
    mapfile -t ck < <(cookies_flag)
    run -x --audio-format mp3 --audio-quality 0 --no-playlist \
        -o "%(title)s [%(id)s].%(ext)s" "${ck[@]}" -- "$@"
    ;;
  subs)
    [ "$#" -ge 1 ] || die "usage: ytdlp.sh subs <url> [url...]"
    for u in "$@"; do validate_url "$u"; done
    ensure_image
    mapfile -t ck < <(cookies_flag)
    run --skip-download --write-subs --write-auto-subs \
        --sub-langs "$SUBLANGS" --convert-subs srt --no-playlist \
        -o "%(title)s [%(id)s].%(ext)s" "${ck[@]}" -- "$@"
    ;;
  thumb)
    [ "$#" -ge 1 ] || die "usage: ytdlp.sh thumb <url> [url...]"
    for u in "$@"; do validate_url "$u"; done
    ensure_image
    mapfile -t ck < <(cookies_flag)
    run --skip-download --write-thumbnail --no-playlist \
        -o "%(title)s [%(id)s].%(ext)s" "${ck[@]}" -- "$@"
    ;;
  meta)
    [ "$#" -eq 1 ] || die "usage: ytdlp.sh meta <url>"
    validate_url "$1"
    ensure_image
    mapfile -t ck < <(cookies_flag)
    run -J --no-playlist "${ck[@]}" -- "$1"
    ;;
  formats)
    [ "$#" -eq 1 ] || die "usage: ytdlp.sh formats <url>"
    validate_url "$1"
    ensure_image
    mapfile -t ck < <(cookies_flag)
    run -F --no-playlist "${ck[@]}" -- "$1"
    ;;
  playlist)
    [ "$#" -ge 1 ] || die "usage: ytdlp.sh playlist <url> [url...]"
    for u in "$@"; do validate_url "$u"; done
    ensure_image
    mapfile -t ck < <(cookies_flag)
    run -f "bv*+ba/b" --merge-output-format mp4 --yes-playlist \
        -o "%(playlist_title)s/%(playlist_index)03d - %(title)s [%(id)s].%(ext)s" \
        "${ck[@]}" -- "$@"
    ;;
  version)
    ensure_image
    run --version
    ;;
  build)
    docker build --build-arg "YTDLP_VERSION=${YTDLP_VERSION}" --build-arg "DENO_VERSION=${DENO_VERSION}" -t "$IMAGE" "$SCRIPT_DIR"
    ;;
  ""|help|-h|--help)
    sed -n '2,40p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
    ;;
  *)
    die "unknown subcommand '$cmd' (try: ytdlp.sh help)"
    ;;
esac
