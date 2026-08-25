<!--
Org-wide default. A repository can override this with its own
.github/PULL_REQUEST_TEMPLATE.md.
-->

## What and why

<!-- What changes, and what problem it solves. Link the issue if there is one. -->

## How it was verified

<!--
Say what you actually ran, not what you intended to run.
Examples:
  - helm template for all environments, diff empty except labels
  - deployed to test2 via /deploy, started a session end to end
  - unit tests: N passing
If it was not verified, say so.
-->

## Deployment impact

<!-- Delete the lines that do not apply. -->

- [ ] Changes a Helm chart (chart `version` bumped)
- [ ] Changes a published image
- [ ] Requires a config change in EduIDE-deployment
- [ ] Requires a cluster-level change (CRDs, Gateway, ClusterRoles)
- [ ] None of the above

## Risk and rollback

<!--
What breaks if this is wrong, and how do you undo it?
"helm rollback" is a fine answer. "Not sure" is also a fine answer - say it.
-->
