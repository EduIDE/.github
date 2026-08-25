#!/usr/bin/env bash
# Regression tests for tag derivation in build-and-push-docker-image.yml.
#
# This does NOT reimplement the logic. It extracts the `derive` step's shell
# body straight out of the workflow YAML and executes it, so the test can never
# drift from what actually runs in CI.
#
# Requires: yq, bash 4+
#
# Run:  ./tests/test-derive-tags.sh

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORKFLOW="${ROOT}/.github/workflows/build-and-push-docker-image.yml"

command -v yq >/dev/null || { echo "yq is required"; exit 2; }
[[ -f "$WORKFLOW" ]] || { echo "not found: $WORKFLOW"; exit 2; }

SCRIPT="$(mktemp)"
yq -r '.jobs.setup.steps[] | select(.id == "derive") | .run' "$WORKFLOW" > "$SCRIPT"
[[ -s "$SCRIPT" ]] || { echo "could not extract the derive step from the workflow"; exit 2; }

if grep -q '\${{' "$SCRIPT"; then
  echo "FAIL: the derive step contains \${{ }} expressions, so it cannot be tested in isolation."
  echo "      Move them into the step's env: block."
  exit 1
fi

FAILED=0

# Runs the real extracted step and prints "base|sha|cache|image" from the
# GITHUB_OUTPUT it produces, or "ERROR <first error line>" if it exits non-zero.
derive() {
  local out; out="$(mktemp)"
  local summary; summary="$(mktemp)"
  local stderr; stderr="$(mktemp)"
  if ( export GITHUB_OUTPUT="$out" GITHUB_STEP_SUMMARY="$summary"; bash "$SCRIPT" ) >"$stderr" 2>&1; then
    printf '%s|%s|%s|%s' \
      "$(grep '^base_tag='    "$out" | cut -d= -f2-)" \
      "$(grep '^sha_tag='     "$out" | cut -d= -f2-)" \
      "$(grep '^cache_tag='   "$out" | cut -d= -f2-)" \
      "$(grep '^cache_image=' "$out" | cut -d= -f2-)"
  else
    printf 'ERROR %s' "$(grep -o '::error::.*' "$stderr" | head -1 | sed 's/::error:://')"
  fi
  rm -f "$out" "$summary" "$stderr"
}

expect() { # <name> <exact expected> [ENV=val ...]
  local name="$1" want="$2"; shift 2
  local got
  got="$( export GITHUB_SHA=abc1234567890 GITHUB_REF_NAME=main GITHUB_REF=refs/heads/main \
                 GITHUB_EVENT_NAME=push GITHUB_REPOSITORY=EduIDE/Example \
                 OVERRIDE="" PR_NUMBER="" RELEASE_TAG="" \
                 BUILD_AMD64=true BUILD_ARM64=true \
                 CACHE_IMAGE_IN="" IMAGE_NAME="eduide/example"
          for kv in "$@"; do export "$kv"; done
          derive )"
  if [[ "$got" == "$want" ]]; then
    printf '  PASS  %-32s %s\n' "$name" "$got"
  else
    printf '  FAIL  %-32s\n        got:  %s\n        want: %s\n' "$name" "$got" "$want"
    FAILED=1
  fi
}

IMG="eduide/example"

echo "=== tag derivation (base|sha|cache|cache_image) ==="
expect "push to main"          "latest|latest-abc1234|build-cache|$IMG"
expect "push to master"        "latest|latest-abc1234|build-cache|$IMG"                    GITHUB_REF=refs/heads/master GITHUB_REF_NAME=master
expect "pull request"          "pr-451|pr-451-abc1234|build-cache-pr-451|$IMG"             GITHUB_EVENT_NAME=pull_request PR_NUMBER=451
expect "release v2.3.0"        "2.3.0|2.3.0-abc1234|build-cache-2.3.0|$IMG"                GITHUB_EVENT_NAME=release RELEASE_TAG=v2.3.0
expect "release without v"     "1.1.0|1.1.0-abc1234|build-cache-1.1.0|$IMG"                GITHUB_EVENT_NAME=release RELEASE_TAG=1.1.0
expect "release candidate"     "2.3.0-rc.1|2.3.0-rc.1-abc1234|build-cache-2.3.0-rc.1|$IMG" GITHUB_EVENT_NAME=release RELEASE_TAG=v2.3.0-rc.1
expect "release-train override" "2.3.0|2.3.0-abc1234|build-cache-2.3.0|$IMG"               OVERRIDE=2.3.0
expect "feature branch"        "feat-foo_bar|feat-foo_bar-abc1234|build-cache-feat-foo_bar|$IMG" GITHUB_REF=refs/heads/feat/foo_bar GITHUB_REF_NAME=feat/foo_bar
expect "uppercase branch"      "feat-abc|feat-abc-abc1234|build-cache-feat-abc|$IMG"       GITHUB_REF=refs/heads/Feat/ABC GITHUB_REF_NAME=Feat/ABC
expect "custom cache image"    "latest|latest-abc1234|build-cache|eduide/shared-cache"     CACHE_IMAGE_IN=eduide/shared-cache

echo
echo "=== no trailing hyphen (regression: 1.1.0- and 1.1.0--375ef32 reached GHCR) ==="
expect "release tag is exact"  "2.3.0|2.3.0-abc1234|build-cache-2.3.0|$IMG"                GITHUB_EVENT_NAME=release RELEASE_TAG=v2.3.0
expect "branch tag is exact"   "my-branch|my-branch-abc1234|build-cache-my-branch|$IMG"    GITHUB_REF=refs/heads/my-branch GITHUB_REF_NAME=my-branch

echo
echo "=== guards ==="
expect "PR without number"     "ERROR pull_request event but no PR number available"       GITHUB_EVENT_NAME=pull_request PR_NUMBER=
expect "release without tag"   "ERROR release event but release.tag_name is empty"         GITHUB_EVENT_NAME=release RELEASE_TAG=
expect "no platform selected"  "ERROR build-amd64 and build-arm64 are both false; nothing to build" BUILD_AMD64=false BUILD_ARM64=false
expect "malformed tag v.1.1.1" "ERROR derived tag '.1.1.1' is not a valid Docker tag."     GITHUB_EVENT_NAME=release RELEASE_TAG=v.1.1.1
expect "tag starting with -"   "ERROR derived tag '-nope' is not a valid Docker tag."      OVERRIDE=-nope

echo
echo "=== artifact key: no image name may prefix-match another ==="
# The merge job downloads digests by glob. A bare slug lets one image swallow
# another's digests when one name is a prefix of another - "...-c-*" also
# matches "...-c-templates-amd64". That shipped once and produced manifests
# containing the wrong image's digests for c, java-17 and rust.
key_for() {
  local out; out="$(mktemp)"
  ( export GITHUB_SHA=abc1234567890 GITHUB_REF_NAME=main GITHUB_REF=refs/heads/main \
           GITHUB_EVENT_NAME=push GITHUB_REPOSITORY=EduIDE/Example \
           OVERRIDE="" PR_NUMBER="" RELEASE_TAG="" BUILD_AMD64=true BUILD_ARM64=true \
           CACHE_IMAGE_IN="" IMAGE_NAME="$1" GITHUB_OUTPUT="$out" \
           GITHUB_STEP_SUMMARY=/dev/null
    bash "$SCRIPT" >/dev/null 2>&1 )
  grep '^artifact_key=' "$out" | cut -d= -f2-
  rm -f "$out"
}

# Every colliding pair that actually exists in the EduIDE image set.
for pair in \
  "eduide/eduide/c:eduide/eduide/c-templates" \
  "eduide/eduide/java-17:eduide/eduide/java-17-templates" \
  "eduide/eduide/java-17:eduide/eduide/java-17-no-ls" \
  "eduide/eduide/rust:eduide/eduide/rust-no-ls" \
  "eduide/eduide/base:eduide/eduide/base-extra"
do
  short="${pair%%:*}"; long="${pair##*:}"
  ks="$(key_for "$short")"; kl="$(key_for "$long")"
  if [[ "$kl" == "$ks"* ]]; then
    printf '  FAIL  %-42s glob "%s-*" would also match "%s"\n' "$short vs $long" "$ks" "$kl"
    FAILED=1
  else
    printf '  PASS  %-42s %s  vs  %s\n' "$short vs $long" "$ks" "$kl"
  fi
done

rm -f "$SCRIPT"
echo
if [[ $FAILED -eq 0 ]]; then echo "ALL PASS"; else echo "SOME FAILED"; fi
exit $FAILED
