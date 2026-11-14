# EduIDE `.github`

Org-level defaults and shared reusable workflows for the [EduIDE](https://github.com/EduIDE) organisation.

## Reusable workflows

### `build-and-push-docker-image.yml`

Builds a container image for **linux/amd64 and linux/arm64** on GitHub-hosted
runners and publishes one multi-arch manifest. Every EduIDE image goes through
this workflow.

```yaml
jobs:
  build:
    uses: EduIDE/.github/.github/workflows/build-and-push-docker-image.yml@v1
    with:
      image-name: eduide/eduide-cloud/service
      docker-file: dockerfiles/service/Dockerfile
    secrets: inherit
```

**Tags published** (both point at the same manifest):

| Trigger | `base_tag` | also published |
|---|---|---|
| push to `main` | `latest` | `latest-<sha7>` |
| pull request | `pr-<N>` | `pr-<N>-<sha7>` |
| release `v2.3.0` | `2.3.0` | `2.3.0-<sha7>` |
| other branch | `<branch-slug>` | `<branch-slug>-<sha7>` |
| `image-tag` input | that value | `<value>-<sha7>` |

The leading `v` is stripped from release tags so that a Helm chart's
`appVersion` and the image tag it refers to are the same string.

**Inputs** (all optional except `image-name`): `image-name`, `docker-file`,
`docker-context`, `ref`, `build-args`, `labels`, `image-tag`, `registry`,
`cache-image`, `no-cache`, `free-disk-space`, `build-amd64`, `build-arm64`.

**Outputs:** `image_tag`, `base_tag`, `sha_tag`, `cache_tag`, `image_repo`.
Use `sha_tag` when one image must build on top of another:

```yaml
build-args: |
  BASE_IDE_TAG=${{ needs.build-base.outputs.sha_tag }}
```

**Secrets:** `registry-user`, `registry-password` (both default to the GitHub
token), and `docker-secrets` for build-time secrets such as `SENTRY_AUTH_TOKEN`.

#### Design decisions worth knowing

- **Both architectures are always built, including on pull requests.** A PR image
  that exists only for amd64 cannot be scheduled onto an arm64 node, which our
  test clusters have. Building one architecture is possible via `build-amd64` /
  `build-arm64` but is intended for debugging only.
- **GitHub-hosted runners only.** There is deliberately no `execution-mode` input
  and no self-hosted or ARC path, so what CI proves is what ships.
- **`free-disk-space` defaults to `true`.** The runner image ships ~30GB of
  toolchains we never use, and the Theia IDE images are large enough that
  reclaiming it is the difference between a green build and `ENOSPC`.
- **Push-by-digest, then merge.** Each architecture pushes an untagged digest;
  a final job assembles the manifest list. A partial failure therefore never
  publishes a half-built tag.
- **The manifest is verified after publishing.** A silently single-architecture
  image is the failure this workflow exists to prevent, so the merge job asserts
  the platforms are actually present rather than trusting the build.
- **`printf`, not `echo`, when slugging tags.** `echo | tr -c` turns the trailing
  newline into a hyphen. That bug published `1.1.0-` and `1.1.0--375ef32` to
  GHCR before this workflow existed; `tests/test-derive-tags.sh` guards it.

### `release.yml` and `release-publish.yml`

`release.yml` validates a version, takes the release notes from
`CHANGELOG.md` and creates a **draft** GitHub Release on the dispatched
commit. Each repository has a thin `release.yml` (`workflow_dispatch`, input
`version`) that calls it, then runs its own build, publish and verify jobs with
`needs: release`, and ends with `release-publish.yml`, which publishes the
draft. The tag only appears at that last step, so a failed build leaves a
draft and no tag.

```yaml
jobs:
  release:
    uses: EduIDE/.github/.github/workflows/release.yml@main
    permissions:
      contents: write
    with:
      version: ${{ inputs.version }}   # X.Y.Z or X.Y.Z-rc.N, no leading v
      tag_prefix: "v"
      changelog_heading: "## [{version}]"

  # build, publish and verify jobs with needs: release

  publish-release:
    needs: [release, verify]
    uses: EduIDE/.github/.github/workflows/release-publish.yml@main
    permissions:
      contents: write
    with:
      tag: ${{ needs.release.outputs.tag }}
```

**Inputs of `release.yml`:** `version` (required), `tag_prefix` (default `v`),
`changelog_path` (default `CHANGELOG.md`), `changelog_heading` (default
`## [{version}]`, `{version}` is replaced), `version_check` (optional bash run
in the checkout with `$VERSION` set; a non-zero exit fails; skipped for release
candidates). Pass `version_check` only where a file in the repository states
the version (a `Chart.yaml`) or another invariant of the released commit must
hold; repositories that stamp the version at build time pass none.

**Outputs:** `tag`, `prerelease` (`true`/`false`), `sha`.

**Refuses:** a malformed version, an existing tag, a version not newer than the
last release with the same prefix, a stable version dispatched from a branch
other than `main`, and a missing or empty CHANGELOG section. A release
candidate without a section of its own falls back to `## [Unreleased]`.

**Reruns:** "Re-run failed jobs" keeps the draft of the first attempt. A new
dispatch of the same version replaces a leftover draft of that tag, so drafts
never pile up. Asset uploads (`gh release upload`) and `gh release view` work
on a draft by tag name.

A tag or Release created with `GITHUB_TOKEN` starts no other workflow, so the
caller must run its publish jobs itself.

## Tests

```bash
./tests/test-derive-tags.sh   # requires yq
```

The test extracts the tag-derivation shell directly out of the workflow YAML and
executes it, so it cannot drift from what runs in CI.

## Versioning

Consumers should pin the `v1` tag. Breaking changes to inputs or outputs get a
new major tag.
