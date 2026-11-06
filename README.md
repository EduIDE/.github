# EduIDE `.github`

Org-level defaults and shared reusable workflows for the [EduIDE](https://github.com/EduIDE) organisation.

## Reusable workflows

Every repository runs the same baseline:

| Workflow file in the repository | Calls | Runs |
|---|---|---|
| `hygiene.yml` | `hygiene.yml@v1` | actionlint, dependency review (PRs only), tag format (tags only), AGENTS.md path check |
| `auto-assign.yml` | `auto-assign.yml@v1` | assigns a PR to its author |
| image builds | `build-and-push-docker-image.yml@v1` | multi-arch images |
| chart releases | `chart-release-checks.yml@v1` | chart version bump and publish guard |

Workflows set a top-level `permissions: contents: read` and widen it per job.
Callers pin `@v1`.

### `hygiene.yml`

The checks every repository runs, with their guards inside the reusable
workflow so a caller cannot run them at the wrong time. The caller is the
whole file:

```yaml
name: Hygiene
on:
  pull_request:
  push:
    branches: [main]
    tags: ['*']
  workflow_dispatch:
permissions:
  contents: read
jobs:
  hygiene:
    uses: EduIDE/.github/.github/workflows/hygiene.yml@v1
```

| Job | Runs on | Why it is guarded |
|---|---|---|
| actionlint | PRs and pushes, not tags | |
| Dependency review | PRs only | on a push there is no base to compare, so it fails. That kept Landing-Page and Docs red on `main` |
| Tag format | tag pushes only | enforces `vX.Y.Z` through `check-tag-format.yml` |
| AGENTS.md references | PRs and pushes, not tags | runs `scripts/check-agents-md.sh` when the repository has one. No path filter: a PR that deletes a path AGENTS.md names must fail before the merge, not after |

Input: `fail-on-severity` (default `high`).

### `auto-assign.yml`

Assigns a PR to its author, skipping bots and PRs that already have assignees.
GitHub does not inherit workflows from the org `.github` repository, so each
repository keeps the short caller shown in the file's header. The caller grants
`pull-requests: write`.

### `chart-release-checks.yml`

A chart change always ships under a new version, and a published version is
never overwritten:

- on a **pull request**, every changed chart must carry a version newer than the base branch;
- on a **push**, a changed chart whose version is already published fails. Give the publishing job `needs:` on this one.

```yaml
jobs:
  chart-checks:
    uses: EduIDE/.github/.github/workflows/chart-release-checks.yml@v1
    with:
      charts: charts/eduide charts/eduide-cluster
  release:
    needs: chart-checks
```

Inputs: `charts` (space-separated chart directories), `registry` (default
`oci://ghcr.io/eduide/charts`).

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
- **Version tags are immutable.** A derived tag that looks like `X.Y.Z` fails the
  build when it is already published from a different commit. `latest`, `pr-N`,
  `nightly` and branch tags still move. Rebuilding the same commit stays allowed,
  so a re-run works, and so does the release event that follows a release train
  build. The check compares the `<tag>-<sha7>` tag, so it needs no image labels.
- **`printf`, not `echo`, when slugging tags.** `echo | tr -c` turns the trailing
  newline into a hyphen. That bug published `1.1.0-` and `1.1.0--375ef32` to
  GHCR before this workflow existed; `tests/test-derive-tags.sh` guards it.

## Tests

```bash
./tests/test-derive-tags.sh      # requires yq
./tests/test-tag-format.sh       # requires yq
./tests/test-release-checks.sh   # requires yq and git
```

The tests extract the shell directly out of the workflow YAML and execute it,
so they cannot drift from what runs in CI. `test-release-checks.sh` replaces
`docker` and `helm` with stubs that answer from a list of published references.

## Versioning

Consumers should pin the `v1` tag. Breaking changes to inputs or outputs get a
new major tag.
