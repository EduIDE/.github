# EduIDE

Browser-based programming environments for teaching, running on Kubernetes and
integrated with [Artemis](https://github.com/ls1intum/Artemis).

Students open an exercise and get a full IDE in the browser - no local setup,
no toolchain installation, the same environment for everyone.

📖 **[Documentation](https://eduide.github.io/Docs/)** - for students,
instructors, administrators and developers.

📊 **[Dashboard](https://eduide.github.io/dashboard/)** - open pull requests,
open issues and release state of every public repository, on one page.

## The main repositories

| Repository | What it is |
|---|---|
| [EduIDE](https://github.com/EduIDE/EduIDE) | The IDE itself. Builds the per-language Theia images students work in. |
| [EduIDE-control-plane](https://github.com/EduIDE/EduIDE-control-plane) | The control plane, written in Go: operator, service, authz, agent, pool scaler and landing page. |
| [EduIDE-Helm](https://github.com/EduIDE/EduIDE-Helm) | The Helm charts. How you install EduIDE on a cluster. |
| [EduIDE-deployment](https://github.com/EduIDE/EduIDE-deployment) | The TUM installations: environment configuration and deployment workflows. |
| [Docs](https://github.com/EduIDE/Docs) | The documentation site. |
| [theia-scale-tests](https://github.com/EduIDE/theia-scale-tests) | End-to-end and scalability tests. |

Supporting components: [scorpio](https://github.com/EduIDE/scorpio) (prepares
the workspace: clone, starter templates, Artemis integration),
[EduIDE-Browser-Extension](https://github.com/EduIDE/EduIDE-Browser-Extension)
("Open in EduIDE" button on Git hosts),
[EduIDE-shared-cache](https://github.com/EduIDE/EduIDE-shared-cache)
(shared Gradle and Bazel build cache),
[EduIDE-image-mannheim](https://github.com/EduIDE/EduIDE-image-mannheim)
(example of an installation-specific image),
[eduide-keycloak-theme](https://github.com/EduIDE/eduide-keycloak-theme)
(login theme).

### Replaced in 3.0

EduIDE 3.0 replaced the Java control plane, which began as a fork of Eclipse
Theia Cloud, with the Go control plane. These repositories get no new releases:

| Repository | Replaced by |
|---|---|
| EduIDE-Cloud | operator, service, authz and agent of EduIDE-control-plane |
| EduIDE-Landing-Page | the landing page in EduIDE-control-plane |
| EduIDE-pool-scaler | the pool scaler in EduIDE-control-plane |
| theia-lite-git-proxy | the git proxy in EduIDE-control-plane |
| workspace-garbage-collector | the workspace expiry of the operator |
| EduIDE-data-bridge | the `eduide-session` extension |
| EduIDE-lsp-extension | language servers running inside the IDE image |

## Running it yourself

```bash
# once per cluster
helm install eduide-cluster oci://ghcr.io/eduide/charts/eduide-cluster \
  --version <version> -n eduide-system --create-namespace --set clusterName=<name>

# once per deployment
helm install eduide oci://ghcr.io/eduide/charts/eduide \
  --version <version> -n my-deployment --create-namespace -f my-values.yaml
```

See the [administrator documentation](https://eduide.github.io/Docs/admins/)
for cluster prerequisites and configuration.

---

EduIDE is developed at the
[Applied Education Technologies](https://ase.cit.tum.de/) group, TUM.
It builds on [Eclipse Theia](https://github.com/eclipse-theia/theia) and began as a fork of
[Eclipse Theia Cloud](https://github.com/eclipse-theia/theia-cloud) and [Theia IDE](https://github.com/eclipse-theia/theia-ide).
