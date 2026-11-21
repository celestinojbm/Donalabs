#!/usr/bin/env bash
# Runs every tests/*.test.sh. No Docker daemon needed (tests use tests/fakes/).
set -uo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")" || exit 1
rc=0
for t in ./*.test.sh; do
  bash "$t" || rc=1
  echo
done
[ "$rc" -eq 0 ] && echo "all script tests passed" || echo "script tests FAILED"
exit "$rc"
