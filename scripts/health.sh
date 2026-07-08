#!/usr/bin/env bash
# =============================================================================
# DonaLabs — health check
# Probes each service's health endpoint on its published port and prints a table
# plus the Docker container health status.
# =============================================================================
set -euo pipefail
. "$(dirname "$0")/lib.sh"

require_docker

echo "== Container status =="
dc ps --format 'table {{.Name}}\t{{.Status}}' 2>/dev/null || dc ps
echo
echo "== Endpoint probes =="
printf "%-14s %-8s %s\n" "SERVICE" "HTTP" "URL"
printf "%-14s %-8s %s\n" "-------" "----" "---"

rc=0
while IFS='|' read -r label url; do
  [ -z "$label" ] && continue
  code=$(curl -fsS -o /dev/null -m 5 -w "%{http_code}" "$url" 2>/dev/null || echo "000")
  # any 2xx/3xx counts as reachable (some apps redirect the health path)
  case "$code" in
    2*|3*) printf "${C_GREEN}%-14s %-8s %s${C_RESET}\n" "$label" "$code" "$url" ;;
    *)     printf "${C_RED}%-14s %-8s %s${C_RESET}\n" "$label" "$code" "$url"; rc=1 ;;
  esac
done < <(health_targets)

echo
if [ "$rc" -eq 0 ]; then ok "all probed services reachable"; else warn "one or more services not reachable"; fi
exit "$rc"
