#!/usr/bin/env bash
# The grammar in check-tag-format.yml, exercised against the tags the org has
# actually produced. Extracted from the workflow rather than restated, so the
# two cannot drift.

set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WF="$ROOT/.github/workflows/check-tag-format.yml"
FAILED=0
ok()  { printf '  PASS  %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; FAILED=1; }

SEMVER=$(yq -r '.jobs.check.steps[0].run' "$WF" | grep -oE "SEMVER='.*'" | sed "s/SEMVER='//;s/'$//")
[[ -n "$SEMVER" ]] || { echo "could not extract the pattern from $WF"; exit 1; }
echo "pattern: $SEMVER"
echo

accept() { [[ "$1" =~ $SEMVER ]]; }

echo "=== must accept ==="
for t in v2.0.0 v1.1.0 v2.1.0-rc.1 v10.20.30 v1.0.0-next.7 v0.1.0 v2.0.0-pr.24.abc1234; do
  accept "$t" && ok "$t" || bad "should accept $t"
done

echo
echo "=== must reject (all three spellings this org has actually used) ==="
for t in 1.1.0 v.1.1.1 V2.0.0 release-1.1.0 v1.1 v1.1.0.1 latest main "v1.1.0 " "" theia-workspace-garbage-collector-0.1.0; do
  accept "$t" && bad "should reject '${t:-<empty>}'" || ok "rejects '${t:-<empty>}'"
done

echo
[[ $FAILED -eq 0 ]] && echo "ALL PASS" || echo "SOME FAILED"
exit $FAILED
