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

## Tests

```bash
./tests/test-derive-tags.sh   # requires yq
```

The test extracts the tag-derivation shell directly out of the workflow YAML and
executes it, so it cannot drift from what runs in CI.

## Versioning

Consumers should pin the `v1` tag. Breaking changes to inputs or outputs get a
new major tag.
