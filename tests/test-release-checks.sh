#!/usr/bin/env bash
# Regression tests for the "published versions are immutable" checks:
#   - the "Release tags are immutable" step in build-and-push-docker-image.yml
#   - the "Check" step in chart-release-checks.yml
#
# Like test-derive-tags.sh, this extracts the step's shell straight out of the
# workflow YAML and runs it. docker and helm are replaced by stubs on PATH that
# answer from a list of "published" references.
#
# Requires: yq, git, bash 4+
#
# Run:  ./tests/test-release-checks.sh

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WF_DIR="${ROOT}/.github/workflows"
command -v yq >/dev/null || { echo "yq is required"; exit 2; }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
FAILED=0

check() { # <name> <want: pass|fail> <got exit code> <output>
  local name="$1" want="$2" code="$3" out="$4" got=pass
  [[ "$code" -ne 0 ]] && got=fail
  if [[ "$got" == "$want" ]]; then
    printf '  PASS  %-52s %s\n' "$name" "$(grep -o '::error[^:]*::.*' <<<"$out" | head -1 | sed 's/::error[^:]*:://')"
  else
    printf '  FAIL  %-52s wanted %s, got %s\n%s\n' "$name" "$want" "$got" "$out"
    FAILED=1
  fi
}

# Stubs: `docker buildx imagetools inspect <ref>` and `helm show chart <ref> --version <v>`
# succeed only for references listed in $PUBLISHED. `helm registry login` always works.
mkdir -p "$WORK/bin"
cat > "$WORK/bin/docker" <<'STUB'
#!/usr/bin/env bash
grep -qxF "$4" "$PUBLISHED"
STUB
cat > "$WORK/bin/helm" <<'STUB'
#!/usr/bin/env bash
[[ "$1" == registry ]] && exit 0
grep -qxF "$3:$5" "$PUBLISHED"
STUB
chmod +x "$WORK/bin/docker" "$WORK/bin/helm"
export PUBLISHED="$WORK/published"

echo "=== release image tags are immutable ==="
IMG_SCRIPT="$WORK/immutable.sh"
yq -r '.jobs.setup.steps[] | select(.id == "immutable") | .run' "$WF_DIR/build-and-push-docker-image.yml" > "$IMG_SCRIPT"
[[ -s "$IMG_SCRIPT" ]] || { echo "could not extract the immutable step"; exit 2; }
if grep -q '\${{' "$IMG_SCRIPT"; then echo "FAIL: the step uses \${{ }}; move it into env:"; exit 1; fi

image() { # <name> <want> <base_tag> <sha_tag> [published refs...]
  local name="$1" want="$2" base="$3" sha="$4"; shift 4
  printf '%s\n' "$@" > "$PUBLISHED"
  local out code
  out="$(PATH="$WORK/bin:$PATH" IMAGE=ghcr.io/eduide/x BASE_TAG="$base" SHA_TAG="$sha" bash "$IMG_SCRIPT" 2>&1)"; code=$?
  check "$name" "$want" "$code" "$out"
}
image "new version"                      pass 2.3.0 2.3.0-abc1234
image "version exists from same commit"  pass 2.3.0 2.3.0-abc1234 ghcr.io/eduide/x:2.3.0 ghcr.io/eduide/x:2.3.0-abc1234
image "version exists from other commit" fail 2.3.0 2.3.0-abc1234 ghcr.io/eduide/x:2.3.0 ghcr.io/eduide/x:2.3.0-0000000
image "release candidate exists"         fail 2.3.0-rc.1 2.3.0-rc.1-abc1234 ghcr.io/eduide/x:2.3.0-rc.1
image "latest may move"                  pass latest latest-abc1234 ghcr.io/eduide/x:latest
image "pr tag may move"                  pass pr-12 pr-12-abc1234 ghcr.io/eduide/x:pr-12
image "nightly may move"                 pass nightly nightly-abc1234 ghcr.io/eduide/x:nightly

echo
echo "=== chart version checks ==="
CHART_SCRIPT="$WORK/chart.sh"
yq -r '.jobs.check.steps[] | select(.name == "Check") | .run' "$WF_DIR/chart-release-checks.yml" > "$CHART_SCRIPT"
[[ -s "$CHART_SCRIPT" ]] || { echo "could not extract the chart check step"; exit 2; }
if grep -q '\${{' "$CHART_SCRIPT"; then echo "FAIL: the step uses \${{ }}; move it into env:"; exit 1; fi

# A repository with two charts, a bare remote standing in for origin, and main
# at version 1.0.0.
REPO="$WORK/repo"
git init -q --bare "$WORK/origin.git"
git init -q -b main "$REPO"
(
  cd "$REPO"
  git config user.email t@t; git config user.name t
  for c in alpha beta; do
    mkdir -p "charts/$c"
    printf 'name: %s\nversion: 1.0.0\n' "$c" > "charts/$c/Chart.yaml"
    echo "x: 1" > "charts/$c/values.yaml"
  done
  git add -A; git commit -qm base
  git remote add origin "$WORK/origin.git"; git push -q origin main
)
BASE_SHA="$(git -C "$REPO" rev-parse HEAD)"

# <name> <want> <event> <charts> <setup commands run in the repo on a fresh branch> [published...]
chart() {
  local name="$1" want="$2" event="$3" charts="$4" setup="$5"; shift 5
  printf '%s\n' "$@" > "$PUBLISHED"
  git -C "$REPO" checkout -q -B "t$RANDOM" "$BASE_SHA"
  ( cd "$REPO" && eval "$setup" && git add -A && git commit -qm change --allow-empty )
  local out code
  out="$(cd "$REPO" && PATH="$WORK/bin:$PATH" GITHUB_EVENT_NAME="$event" CHARTS="$charts" \
          REGISTRY=oci://ghcr.io/eduide/charts BASE_REF=main BEFORE="$BASE_SHA" \
          GHCR_TOKEN=x GITHUB_ACTOR=t bash "$CHART_SCRIPT" 2>&1)"; code=$?
  check "$name" "$want" "$code" "$out"
}
bump_alpha='sed -i.bak "s/^version: .*/version: 1.0.1/" charts/alpha/Chart.yaml && rm charts/alpha/Chart.yaml.bak'
touch_alpha='echo "x: 2" > charts/alpha/values.yaml'

chart "PR: change without bump"            fail pull_request "charts/alpha charts/beta"   "$touch_alpha"
chart "PR: trailing slash still checks"     fail pull_request "charts/alpha/ charts/beta/" "$touch_alpha"
chart "PR: change with bump"                pass pull_request "charts/alpha charts/beta"   "$touch_alpha && $bump_alpha"
chart "PR: nothing changed"                 pass pull_request "charts/alpha charts/beta"   "true"
chart "PR: new chart"                       pass pull_request "charts/alpha charts/gamma"  'mkdir -p charts/gamma && printf "name: gamma\nversion: 0.1.0\n" > charts/gamma/Chart.yaml'
chart "push: changed, version published"    fail push         "charts/alpha charts/beta"   "$touch_alpha" oci://ghcr.io/eduide/charts/alpha:1.0.0
chart "push: changed, version new"          pass push         "charts/alpha charts/beta"   "$touch_alpha && $bump_alpha" oci://ghcr.io/eduide/charts/alpha:1.0.0
chart "push: unchanged, version published"  pass push         "charts/alpha charts/beta"   "true" oci://ghcr.io/eduide/charts/alpha:1.0.0
chart "dispatch: nothing to compare"        pass workflow_dispatch "charts/alpha"          "$touch_alpha" oci://ghcr.io/eduide/charts/alpha:1.0.0

echo
if [[ $FAILED -eq 0 ]]; then echo "ALL PASS"; else echo "SOME FAILED"; fi
exit $FAILED
