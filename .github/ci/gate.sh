#!/usr/bin/env bash
# =============================================================================
# DonaLabs CI — verdict of the always-on aggregator job ("CI OK").
#
# This is the ONE check to mark as required in branch protection. It runs on
# every PR (no path filter) and fails unless:
#   - the `changes` job succeeded, and
#   - every area it selected ran and succeeded, and
#   - every area it did NOT select was skipped (or succeeded).
#
# Inputs (environment), straight from the `needs` context:
#   CHANGES_RESULT                  needs.changes.result
#   DS_NEEDED,    DS_RESULT         needs.changes.outputs.design_system / needs.design-system.result
#   INFRA_NEEDED, INFRA_RESULT      needs.changes.outputs.infra / needs.infra.result
#
# Results are one of: success, failure, cancelled, skipped (or empty).
# =============================================================================
set -uo pipefail

rc=0
line() { printf '%-16s %s\n' "$1" "$2"; }
bad()  { line "$1" "FAIL  $2"; rc=1; }
good() { line "$1" "ok    $2"; }

if [ "${CHANGES_RESULT:-}" = "success" ]; then
  good changes "routing computed"
else
  bad changes "routing job result='${CHANGES_RESULT:-<empty>}': cannot tell what had to run"
fi

check_area() {
  local name="$1" needed="$2" result="$3"
  case "$needed" in
    true)
      if [ "$result" = "success" ]; then good "$name" "required, passed"
      else bad "$name" "required, result='${result:-<empty>}'"; fi ;;
    false)
      case "$result" in
        skipped|success) good "$name" "not affected by this change" ;;
        *) bad "$name" "not required but result='${result:-<empty>}'" ;;
      esac ;;
    *)
      bad "$name" "unknown routing value '${needed:-<empty>}'" ;;
  esac
}

check_area design-system "${DS_NEEDED:-}"    "${DS_RESULT:-}"
check_area infra         "${INFRA_NEEDED:-}" "${INFRA_RESULT:-}"

if [ "$rc" -eq 0 ]; then echo "CI OK"; else echo "CI FAILED"; fi
exit "$rc"
