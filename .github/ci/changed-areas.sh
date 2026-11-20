#!/usr/bin/env bash
# =============================================================================
# DonaLabs CI — decide which validation areas a change touches.
#
# Used by the `changes` job of .github/workflows/ci.yml. Pure bash + git, no
# third-party action, so the routing logic is versioned and tested here
# (tests/ci.test.sh).
#
# Inputs (environment):
#   EVENT_NAME   github.event_name (pull_request, merge_group, push, ...)
#   BASE_SHA     commit to diff from (PR base, merge-group base, push "before")
#   HEAD_SHA     commit to diff to   (PR head, merge-group head, push "after")
#   CHANGED_FILES_FILE  optional: read the file list from here instead of git
#                       (one path per line; used by the tests)
#
# Output: "design_system=true|false" and "infra=true|false", appended to
# $GITHUB_OUTPUT when set, always echoed to stdout. A human-readable table goes
# to $GITHUB_STEP_SUMMARY when set.
#
# Fail-safe: when the range cannot be computed (manual run, first push of a
# branch, force-push to an unknown commit, git error) EVERY area runs. Skipping
# validation must be a positive decision, never the result of an error.
# =============================================================================
set -euo pipefail

ZERO_SHA="0000000000000000000000000000000000000000"

# path -> area. Mirrors the old per-workflow `paths:` filters (a bare `*` does
# not cross "/", so `*.sh` means root-level scripts only). Keep in sync with
# the README "Continuous integration" table.
classify() {
  case "$1" in
    # The CI wiring itself: a bad edit here could silently skip everything,
    # so it re-validates every area.
    .github/workflows/ci.yml|.github/ci/*)       echo "all" ;;
    design-system/*|.github/workflows/design-system.yml) echo "design_system" ;;
    services/*|proxy/*|scripts/*|tests/*|docker-compose.yml|.env.example|.github/workflows/infra.yml) echo "infra" ;;
    */*)                                          echo "none" ;;
    *.sh)                                         echo "infra" ;;
    *)                                            echo "none" ;;
  esac
}

emit() {
  local key="$1" val="$2"
  echo "${key}=${val}"
  if [ -n "${GITHUB_OUTPUT:-}" ]; then echo "${key}=${val}" >> "$GITHUB_OUTPUT"; fi
}

summary() { if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then printf '%s\n' "$@" >> "$GITHUB_STEP_SUMMARY"; fi; }

run_all() {
  echo "::notice::$1 — running every validation area"
  summary "### Changed areas" "" "$1 → **all areas run**."
  emit design_system true
  emit infra true
  exit 0
}

# --- 1. collect the changed files ---------------------------------------------
if [ -n "${CHANGED_FILES_FILE:-}" ]; then
  FILES="$(cat "$CHANGED_FILES_FILE")"
else
  case "${EVENT_NAME:-}" in
    pull_request|pull_request_target|merge_group|push) ;;
    *) run_all "event '${EVENT_NAME:-<none>}' has no diff range" ;;
  esac
  if [ -z "${BASE_SHA:-}" ] || [ "${BASE_SHA}" = "$ZERO_SHA" ] || [ -z "${HEAD_SHA:-}" ]; then
    run_all "no base commit (new branch or missing SHA)"
  fi
  # --no-renames: list BOTH sides of a rename, so moving a file out of an area
  # still validates the area it left.
  # Three-dot: changes on the head side since the merge base, i.e. what the PR
  # actually introduces, regardless of how far main has moved since.
  if ! FILES="$(git diff --name-only --no-renames "${BASE_SHA}...${HEAD_SHA}" 2>/dev/null)"; then
    run_all "could not diff ${BASE_SHA:0:12}...${HEAD_SHA:0:12}"
  fi
fi

# --- 2. classify ----------------------------------------------------------------
ds=false infra=false
declare -a unrouted=()
n=0
while IFS= read -r f; do
  [ -n "$f" ] || continue
  n=$((n+1))
  case "$(classify "$f")" in
    all)           ds=true; infra=true ;;
    design_system) ds=true ;;
    infra)         infra=true ;;
    none)          unrouted+=("$f") ;;
  esac
done <<< "$FILES"

summary "### Changed areas" "" \
  "| Area | Runs |" "|---|---|" \
  "| design-system | ${ds} |" "| infrastructure | ${infra} |" "" \
  "${n} file(s) changed."
if [ "${#unrouted[@]}" -gt 0 ]; then
  # Not an error (docs, README...), but make it visible: a NEW top-level
  # directory lands here too and gets no validation until it is routed above.
  summary "" "<details><summary>${#unrouted[@]} file(s) outside any validated area</summary>" ""
  for f in "${unrouted[@]}"; do summary "- \`$f\`"; done
  summary "" "</details>"
fi

emit design_system "$ds"
emit infra "$infra"
