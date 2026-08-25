# Security Policy

Org-wide default for all repositories under [EduIDE](https://github.com/EduIDE).

## Reporting a vulnerability

**Do not open a public issue.** Report privately through GitHub security
advisories:

<https://github.com/EduIDE/.github/security/advisories/new>

If the vulnerability is specific to one repository, use that repository's
"Report a vulnerability" button instead so the advisory lands with the code.

Please include what you can:

- which component and version (image tag or chart version)
- what an attacker can do with it
- how to reproduce
- whether it is already public anywhere

## Scope

EduIDE runs untrusted student code in per-session containers on a shared
Kubernetes cluster. Findings that are especially relevant:

- escaping a session container, or reaching another user's session or workspace
- reading another user's workspace storage
- bypassing Keycloak authentication or the oauth2-proxy layer in front of a session
- reaching the operator, the REST service, or their service accounts from inside a session
- privilege escalation via the admin API token

Denial of service caused by a session consuming its own quota is expected
behaviour, not a vulnerability. Resource limits are enforced per AppDefinition.

## What to expect

We will acknowledge the report, tell you whether we consider it in scope, and
keep you informed while we work on a fix. We will credit you in the advisory
unless you would rather stay anonymous.
