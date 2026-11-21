#!/usr/bin/env bash
# Tests for the CI routing (.github/ci/changed-areas.sh) and the aggregator
# verdict (.github/ci/gate.sh). Pure bash + git; no network, no Docker.
#   bash tests/ci.test.sh
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/.." && pwd)"
ROUTE="$REPO/.github/ci/changed-areas.sh"
GATE="$REPO/.github/ci/gate.sh"

PASS=0 FAIL=0
pass() { PASS=$((PASS+1)); printf '  ok    %s\n' "$1"; }
fail() { FAIL=$((FAIL+1)); printf '  FAIL  %s\n' "$1"; [ -z "${2:-}" ] || printf '        %s\n' "$2"; }
eq()   { if [ "$2" = "$3" ]; then pass "$1"; else fail "$1" "expected '$3', got '$2'"; fi; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# route <files...> -> prints "ds,infra" for that changed-file list
route() {
  printf '%s\n' "$@" > "$TMP/files"
  local out ds infra
  out="$(CHANGED_FILES_FILE="$TMP/files" GITHUB_OUTPUT='' GITHUB_STEP_SUMMARY='' bash "$ROUTE")"
  ds="$(sed -n 's/^design_system=//p' <<< "$out")"
  infra="$(sed -n 's/^infra=//p' <<< "$out")"
  echo "${ds},${infra}"
}

echo "changed-areas.sh: path routing"
eq "design-system source"            "$(route design-system/packages/ui/src/button.tsx)"   "true,false"
eq "design-system lockfile"          "$(route design-system/pnpm-lock.yaml)"               "true,false"
eq "design-system workflow"          "$(route .github/workflows/design-system.yml)"        "true,false"
eq "service compose"                 "$(route services/n8n/docker-compose.yml)"            "false,true"
eq "proxy"                           "$(route proxy/Caddyfile)"                            "false,true"
eq "scripts/"                        "$(route scripts/restore.sh)"                         "false,true"
eq "tests/ (script tests)"           "$(route tests/backup.test.sh)"                       "false,true"
eq "root compose"                    "$(route docker-compose.yml)"                         "false,true"
eq "root *.sh"                       "$(route backup.sh)"                                  "false,true"
eq ".env.example"                    "$(route .env.example)"                               "false,true"
eq "infra workflow"                  "$(route .github/workflows/infra.yml)"                "false,true"
eq "nested *.sh outside areas is not infra" "$(route docs/examples/hook.sh)"               "false,false"
eq "README only -> nothing runs"     "$(route README.md)"                                  "false,false"
eq "docs only -> nothing runs"       "$(route docs/security.md docs/architecture.md)"      "false,false"
eq "design-system/README counts as design-system" "$(route design-system/README.md)"       "true,false"
eq "lookalike prefix is not an area" "$(route design-systems/x.ts servicesX/y.yml)"        "false,false"
eq "mixed change -> both"            "$(route design-system/a.ts services/n8n/x.yml)"      "true,true"
eq "ci.yml -> everything"            "$(route .github/workflows/ci.yml)"                   "true,true"
eq "router script -> everything"     "$(route .github/ci/changed-areas.sh)"                "true,true"
eq "empty diff -> nothing runs"      "$(route '')"                                         "false,false"

# GITHUB_OUTPUT / GITHUB_STEP_SUMMARY are written in the format Actions expects.
printf 'design-system/a.ts\nREADME.md\n' > "$TMP/files"
: > "$TMP/out"; : > "$TMP/sum"
CHANGED_FILES_FILE="$TMP/files" GITHUB_OUTPUT="$TMP/out" GITHUB_STEP_SUMMARY="$TMP/sum" bash "$ROUTE" >/dev/null
eq "GITHUB_OUTPUT has both keys" "$(sort "$TMP/out" | tr '\n' ' ')" "design_system=true infra=false "
if grep -q 'README.md' "$TMP/sum"; then pass "summary lists files outside any area"; else fail "summary lists files outside any area"; fi

echo
echo "changed-areas.sh: git ranges and fail-safe"
G="$TMP/git"; mkdir -p "$G"
git -C "$G" init -q -b main
git -C "$G" config user.email t@example.invalid; git -C "$G" config user.name t
mkdir -p "$G/design-system" "$G/services/n8n" "$G/docs"
echo a > "$G/design-system/a.ts"; echo b > "$G/services/n8n/compose.yml"; echo c > "$G/docs/x.md"
git -C "$G" add -A; git -C "$G" commit -qm base
BASE="$(git -C "$G" rev-parse HEAD)"

# PR branch touches docs only, while main later changes infra: three-dot diff
# must report only what the PR introduced.
git -C "$G" checkout -qb pr
echo c2 >> "$G/docs/x.md"; git -C "$G" commit -qam "pr: docs"
PR_HEAD="$(git -C "$G" rev-parse HEAD)"
git -C "$G" checkout -q main
echo b2 >> "$G/services/n8n/compose.yml"; git -C "$G" commit -qam "main: infra"
MAIN_TIP="$(git -C "$G" rev-parse HEAD)"

groute() { # groute <event> <base> <head>
  local out
  out="$(cd "$G" && EVENT_NAME="$1" BASE_SHA="$2" HEAD_SHA="$3" GITHUB_OUTPUT='' GITHUB_STEP_SUMMARY='' bash "$ROUTE" 2>/dev/null)"
  echo "$(sed -n 's/^design_system=//p' <<< "$out"),$(sed -n 's/^infra=//p' <<< "$out")"
}
eq "PR vs moved main: only PR's own changes"  "$(groute pull_request "$MAIN_TIP" "$PR_HEAD")" "false,false"
eq "merge_group range"                         "$(groute merge_group "$BASE" "$MAIN_TIP")"    "false,true"
eq "push range"                                "$(groute push "$BASE" "$MAIN_TIP")"           "false,true"

# A rename out of an area must still validate the area it left.
git -C "$G" checkout -qb mv "$BASE"
git -C "$G" mv design-system/a.ts docs/a.ts; git -C "$G" commit -qm "move out"
eq "rename out of design-system still routes it" "$(groute pull_request "$BASE" "$(git -C "$G" rev-parse HEAD)")" "true,false"

ZERO=0000000000000000000000000000000000000000
eq "new branch push (zero before) -> all"   "$(groute push "$ZERO" "$MAIN_TIP")"            "true,true"
eq "missing base -> all"                    "$(groute pull_request "" "$PR_HEAD")"          "true,true"
eq "unknown commit (force-push) -> all"     "$(groute push deadbeefdeadbeefdeadbeefdeadbeefdeadbeef "$MAIN_TIP")" "true,true"
eq "workflow_dispatch -> all"               "$(groute workflow_dispatch "$BASE" "$MAIN_TIP")" "true,true"
eq "no event at all -> all"                 "$(groute "" "$BASE" "$MAIN_TIP")"              "true,true"

echo
echo "gate.sh: verdict"
gate() { # gate <changes> <ds_needed> <ds_result> <infra_needed> <infra_result> -> exit code
  CHANGES_RESULT="$1" DS_NEEDED="$2" DS_RESULT="$3" INFRA_NEEDED="$4" INFRA_RESULT="$5" \
    bash "$GATE" >/dev/null 2>&1 && echo 0 || echo 1
}
eq "docs-only PR: both skipped -> pass"            "$(gate success false skipped false skipped)" 0
eq "design-system ran ok, infra skipped -> pass"   "$(gate success true success false skipped)"  0
eq "both ran ok -> pass"                           "$(gate success true success true success)"   0
eq "required area failed -> fail"                  "$(gate success true failure false skipped)"  1
eq "required area cancelled -> fail"               "$(gate success false skipped true cancelled)" 1
eq "required area skipped anyway -> fail"          "$(gate success true skipped false skipped)"  1
eq "required area with empty result -> fail"       "$(gate success true '' false skipped)"       1
eq "routing failed (areas skipped) -> fail"        "$(gate failure '' skipped '' skipped)"       1
eq "routing cancelled -> fail"                     "$(gate cancelled '' skipped '' skipped)"     1
eq "garbage routing value -> fail"                 "$(gate success maybe skipped false skipped)" 1
eq "unrequired area that failed -> fail"           "$(gate success false failure false skipped)" 1
eq "unrequired area that ran ok -> pass"           "$(gate success false success false skipped)" 0
eq "all inputs missing -> fail"                    "$(gate '' '' '' '' '')"                      1

echo
echo "ci.yml: workflow invariants the gate relies on"
# Pure bash on purpose (the runner's yq flavour and PyYAML availability are not
# guaranteed). The checks read only simple, single-line keys of ci.yml.
CI_YML="$REPO/.github/workflows/ci.yml"
# top <key>: lines of a top-level mapping, up to the next top-level key.
top() { awk -v k="$1:" '$0==k || index($0,k" ")==1 {on=1; print; next} on && /^[^ #]/ {exit} on {print}' "$CI_YML"; }
# job <id>: lines of jobs.<id>, up to the next job.
job() { awk -v k="  $1:" '$0==k {on=1; next} on && /^  [^ #]/ {exit} on && /^[^ #]/ {exit} on {print}' "$CI_YML"; }
ON="$(top on)"
PR_TRIGGER="$(awk '/^  pull_request:/ {on=1; next} on && /^  [^ #]/ {exit} on {print}' <<< "$ON")"
if grep -Eq '^\s+(paths|paths-ignore|branches|branches-ignore):' <<< "$PR_TRIGGER"; then
  fail "pull_request has no path/branch filter" "a filter would leave 'CI OK' pending (or absent) on some PRs"
else pass "pull_request has no path/branch filter"; fi
PR_TYPES="$(sed -n 's/^ *types: *\[\(.*\)\].*/\1/p' <<< "$PR_TRIGGER" | tr -d ' ')"
for t in opened synchronize reopened edited; do
  if [[ ",$PR_TYPES," == *",$t,"* ]]; then pass "pull_request re-runs on '$t'"
  else fail "pull_request re-runs on '$t'" "types=[$PR_TYPES]"; fi
done
GROUP="$(top concurrency | sed -n 's/^ *group: *//p')"
if [[ "$GROUP" == *"github.run_id"* && "$GROUP" == *"github.event_name == 'pull_request'"* ]]; then
  pass "only PR runs share a concurrency group (push/merge_group never superseded)"
else fail "only PR runs share a concurrency group (push/merge_group never superseded)" "group: $GROUP"; fi
if job ci-ok | grep -Eq '^ +if: *always\(\) *$'; then pass "CI OK runs with if: always()"
else fail "CI OK runs with if: always()"; fi
GATE_NEEDS="$(job ci-ok | sed -n 's/^ *needs: *\[\(.*\)\].*/\1/p' | tr -d ' ')"
for j in $(awk '/^jobs:/ {on=1; next} on && /^  [a-z][a-z0-9_-]*:/ {sub(/:.*/,""); sub(/^ +/,""); print}' "$CI_YML"); do
  [ "$j" = ci-ok ] && continue
  if [[ ",$GATE_NEEDS," == *",$j,"* ]]; then pass "CI OK needs '$j'"
  else fail "CI OK needs '$j'" "a job missing from needs is invisible to the gate"; fi
done

echo
echo "ci.test.sh: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
