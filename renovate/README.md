# Renovate

Dependency and security updates for the EduIDE org are driven by [Renovate](https://docs.renovatebot.com/).
All policy lives in one file: [`renovate-config.json`](../renovate-config.json) at the root of this repo.

Every managed repo carries a three-line `renovate.json` that points at it:

```json
{
  "$schema": "https://docs.renovatebot.com/renovate-schema.json",
  "extends": ["local>EduIDE/.github:renovate-config"]
}
```

Change the shared file and the change reaches every repo. That is the whole idea - resist
the urge to solve a problem by editing eleven repo-local configs.

## What the policy does

| | |
|---|---|
| **Security fixes** | Raised immediately, outside the schedule, prefixed `fix(security):` and labeled `security`. Rate limits and the release-age quarantine do not apply. |
| **Everything else** | Batched into Monday 00:00-07:00 Europe/Berlin, grouped into a handful of combined PRs. |
| **Majors** | Never appear unasked. They sit on the Dependency Dashboard until someone ticks the box. |
| **Automerge** | Off everywhere. Deliberate - see below. |
| **Supply chain** | `minimumReleaseAge: 5 days`, so a compromised release that gets yanked within a few days never reaches a PR. |

Groups, roughly one PR each: github actions, npm dependencies, npm dev dependencies,
java dependencies, go modules, container base images, helm charts, deployed image tags,
terraform, eclipse theia, quarkus.

### Why no automerge

Six of the eleven repos have no tests at all, and two more have tests CI does not run.
Compile-level signal catches a dependency that fails to build; it does not catch one that
builds and misbehaves. Turning automerge on is a one-line change to the shared preset once
the test situation improves - `"automerge": true` under whichever `packageRules` entry you
trust.

## Add a new repo

1. Commit the three-line `renovate.json` above to the repo.
2. Add the repo to the Renovate app's **selected repositories** list
   (org settings → GitHub Apps → Renovate → Configure).
3. Enable Dependabot **alerts** and the dependency graph on the repo (Settings → Advanced
   Security). Renovate reads GitHub's advisory alerts, so without this the security path is
   dead. Leave Dependabot *security updates* off - Renovate raises those PRs.
4. Delete any leftover `.github/dependabot.yml` or `.whitesource`.

Repo-specific exclusions belong in `packageRules` with `matchFileNames` and
`"enabled": false` - **not** in a repo-local `ignorePaths`. `ignorePaths` is
`mergeable: false` in Renovate, so setting it in a repo silently replaces the shared list
rather than adding to it.

## Change policy for every repo

Edit `renovate-config.json`, open a PR, merge. Renovate picks up the new preset on its next
run. To force one repo to re-read it immediately, tick the "Check this box to trigger a
request for Renovate to run again" checkbox at the bottom of that repo's Dependency
Dashboard issue.

## Test a change before it hits all eleven repos

The CI job in this repo runs `renovate-config-validator --strict` on every PR that touches
the preset. That catches schema errors, unknown options and deprecations - it does **not**
catch a rule that is valid but does the wrong thing.

For behaviour, point one repo at your branch. Preset references take a git ref suffix:

```json
{ "extends": ["local>EduIDE/.github:renovate-config#my-branch"] }
```

Do that on a throwaway branch of a small repo, let Renovate run, look at the PRs it opens,
then drop the suffix.

To see what Renovate would do without writing anything:

```bash
LOG_LEVEL=debug npx --yes renovate@44.46.7 \
  --platform=github --token="$GITHUB_TOKEN" \
  --dry-run=full --schedule="" --require-config=optional \
  EduIDE/EduIDE EduIDE/EduIDE-deployment
```

`--schedule=""` clears the Monday window so you do not have to wait until Monday.
Grep the output for `Dependency extraction complete` and check the per-manager file counts.
This is the only reliable way to verify a custom manager, because a regex that matches
nothing fails silently and looks identical to a regex that found nothing to update.

Pin the version in that command. An unpinned `npx renovate` resolves to whatever is sitting
in the npx cache, which may be years old and will reject options that are perfectly valid.

## Custom managers

Some things in this org are invisible to Renovate's built-in managers and need a regex
manager. One lives here, one lives in a repo:

- **`EduIDE/package.json` `theiaPlugins`** pins plugin tarballs by GitHub release URL. No
  built-in manager reads custom manifest keys. Covered by the preset.
- **`EduIDE-deployment/environments/*/env.yaml`** carries `spec.platform.chartVersion`.
  These are `eduide.dev/v1 Environment` manifests, so neither `helmv3` nor `helm-values`
  can read them. Covered by that repo's own `renovate.json`, since the file shape is
  specific to it.

**Before adding a manager here, check the path still exists.** The preset briefly shipped a
manager for `deployments/*/values.yaml` in EduIDE-deployment, matching a `preloading.images`
list. That layout had been replaced by `environments/` a day earlier, so the manager matched
nothing. A regex that matches nothing looks exactly like a regex that found nothing to
update - the only way to tell them apart is a dry run.

### Known gap: open-vsx

`theiaPlugins` also pins two VSIXs from open-vsx.org (`vscjava.vscode-java-pack`,
`vscjava.vscode-java-dependency`). Renovate has **no open-vsx datasource**, so these are not
tracked and must be bumped by hand. The only way to automate it today is a
`customDatasources` entry against the open-vsx API, which is still flagged experimental
upstream; not worth the fragility for two pins. Revisit if open-vsx support lands.

## A repo shows "disabled" in the Mend portal

Two different causes, and only one of them is fixable in git.

**It is a fork.** Renovate skips forked repositories by default in autodiscover mode, which is
how the hosted app runs - a valid `renovate.json` does not override this. `EduIDE`,
`EduIDE-Cloud` and `EduIDE-Helm` are forks. The preset sets `"forkProcessing": "enabled"` to
cover them. That is safe only while the app installation is scoped to a **selected**
repository list; if someone widens it to "All repositories", this setting would also start
processing genuine upstream mirrors like `theia`.

**Someone closed its onboarding PR.** Renovate reads a human closing a "Configure Renovate"
PR as declining, and records that against the repo in the Mend portal. This lives in Mend's
database, not in the repo, so **no config change clears it** - re-enable the repo at
<https://developer.mend.io/github/EduIDE>. `EduIDE-deployment` (#40) and
`EduIDE-Landing-Page` (#4) were both declined this way before the current rollout.

Note that Renovate *auto*-closing an onboarding PR is different and harmless - it does that
when it finds a repo is already onboarded, and it does not disable anything.

## Things that are deliberate, not oversights

- **`pinDigests` is off.** Several workflows call `ls1intum/.github/...@feature/...`, which
  is a moving branch. Digest pinning would freeze them at a SHA with no update path - the
  opposite of the intent. Getting those onto tags is a prerequisite for ever turning digest
  pinning on.
- **`rangeStrategy` is `auto`**, which means a caret range like `^4.10.5` produces no PR when
  4.11.0 ships; it reaches the lockfile via monthly `lockFileMaintenance` instead. This keeps
  the noise down. Switch to `"bump"` if you would rather see manifest ranges move every week.
- **`-SNAPSHOT` versions and `org.eclipse.theia.cloud:*` are disabled** - they are reactor
  modules built in-repo, not registry artifacts.
- **`engines.*`, `@types/vscode` and the `go` directive are frozen.** They are compatibility
  floors. Raising them is a decision, not a chore.
