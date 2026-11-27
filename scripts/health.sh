#!/usr/bin/env bash
# =============================================================================
# DonaLabs — health check
# Probes each service's health endpoint on its published port and prints a table
# plus the Docker container health status.
#
# Exit status (safe to use from cron or a deploy script):
#   0  every endpoint answered 2xx/3xx and no container is unhealthy/restarting
#   1  anything else: an endpoint down or erroring, a container reported
#      `unhealthy` or stuck `restarting`, no .env, or nothing was probed at all
#      (a check that checked nothing never reports success)
# =============================================================================
set -euo pipefail
. "$(dirname "$0")/lib.sh"

require_docker
require_env

# Read the targets BEFORE the loop: inside `< <(...)` a failure is invisible and
# the loop would just run zero times, then report success.
targets="$(health_targets)" || { err "could not read the health targets"; exit 1; }

rc=0

echo "== Container status =="
dc ps --format 'table {{.Name}}\t{{.Status}}' 2>/dev/null || dc ps
# A container can still answer HTTP while Docker marks it unhealthy, or answer
# between crashes while it is restart-looping: both make the stack not healthy.
# If Compose cannot list them (e.g. a version without .Health in --format), say
# so: the endpoint probes still decide the exit status, but the skip is visible.
if ps_out="$(dc ps --format '{{.Name}} {{.State}} {{.Health}}' 2>/dev/null)"; then
  bad="$(awk '$2 == "restarting" || $3 == "unhealthy" { print $1 " (" ($3 == "unhealthy" ? "unhealthy" : $2) ")" }' <<< "$ps_out")"
else
  bad=""
  warn "could not read container state/health from docker compose: container health NOT checked"
fi
if [ -n "$bad" ]; then
  rc=1
  while IFS= read -r line; do err "container not healthy: $line"; done <<< "$bad"
fi
echo
echo "== Endpoint probes =="
printf "%-14s %-8s %s\n" "SERVICE" "HTTP" "URL"
printf "%-14s %-8s %s\n" "-------" "----" "---"

probed=0
while IFS='|' read -r label url; do
  [ -z "$label" ] && continue
  probed=$((probed+1))
  # No -f: with it curl exits 22 on 4xx/5xx AFTER printing the code, and a
  # `|| echo 000` fallback then glued "000" onto it ("503000"). Without -f the
  # exit status only means "no HTTP answer", and -w then prints 000 by itself.
  code="$(curl -sS -o /dev/null -m 5 -w '%{http_code}' "$url" 2>/dev/null)" || true
  [[ "$code" =~ ^[0-9]{3}$ ]] || code="000"
  # any 2xx/3xx counts as reachable (some apps redirect the health path)
  case "$code" in
    2*|3*) printf "${C_GREEN}%-14s %-8s %s${C_RESET}\n" "$label" "$code" "$url" ;;
    *)     printf "${C_RED}%-14s %-8s %s${C_RESET}\n" "$label" "$code" "$url"; rc=1 ;;
  esac
done <<< "$targets"

echo
if [ "$probed" -eq 0 ]; then
  err "no endpoint was probed: nothing was checked"
  exit 1
fi
if [ "$rc" -eq 0 ]; then
  ok "all ${probed} probed services reachable"
else
  warn "one or more services not healthy"
fi
exit "$rc"
