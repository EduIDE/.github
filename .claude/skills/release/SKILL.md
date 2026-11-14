---
name: release
description: Release .github. Use when asked to release, publish, or move the v1 tag of the EduIDE .github repository, or to ship a change to the shared workflows. Checks what main changed since v1, asks before moving v1, and verifies the callers.
---

# Releasing .github

This repository has no `release.yml` and no versions. Consumers pin a moving ref:

| Ref | Used by |
|---|---|
| `@v1` | `build-and-push-docker-image.yml`, `dependency-review.yml` in EduIDE, EduIDE-Cloud, EduIDE-Helm, EduIDE-Landing-Page, EduIDE-deployment, workspace-garbage-collector, EduIDE-shared-cache, keycloak-theme |
| `@main` | `release.yml` and `release-publish.yml` (reusable release workflows), `check-tag-format.yml`, Renovate preset `local>EduIDE/.github:renovate-config` |

"Releasing" means moving the `v1` tag to a reviewed commit on `main`. Changes on `main` reach `@main` callers immediately and `@v1` callers only after this.

## Dependencies

None. This repository pins no other EduIDE release.

## 1. See what `v1` would pick up

```bash
git fetch origin --tags
git log --first-parent --format='%h %s' v1..origin/main
git diff --stat v1 origin/main -- .github/workflows
```

Read the merged pull requests behind the commits. Renovate-only commits (dependency pins inside workflows) need no discussion beyond a one-line summary.

## 2. Ask the user

Show the list. Ask whether to move `v1`, and warn when a change alters inputs, outputs, defaults or the tags a workflow publishes: every `@v1` caller changes behaviour at once. A breaking change needs a new major tag (`v2`) instead, and a pull request in each caller; ask before choosing that.

## 3. Move the tag

Only after a yes, and only to a commit on `main` whose CI is green:

```bash
SHA=$(git rev-parse origin/main)
gh run list -R EduIDE/.github --branch main --limit 3
git tag -f v1 "$SHA"
git push origin v1 --force
```

Moving `v1` is an intentional force push of a tag; never touch other tags.

## 4. Verify

Pick one caller that exercises the changed workflow (for example an EduIDE-Helm or workspace-garbage-collector pull request), re-run its CI, and check it uses the new behaviour. Report the commit `v1` now points to and which consumers it reaches (table above).
