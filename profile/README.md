# EduIDE

Browser-based programming environments for teaching, running on Kubernetes and
integrated with [Artemis](https://github.com/ls1intum/Artemis).

Students open an exercise and get a full IDE in the browser - no local setup,
no toolchain installation, the same environment for everyone.

📖 **[Documentation](https://eduide.github.io/Docs/)** - for students,
instructors, administrators and developers.

## The main repositories

| Repository | What it is |
|---|---|
| [EduIDE](https://github.com/EduIDE/EduIDE) | The IDE itself. Builds the per-language Theia images students work in. |
| [EduIDE-Cloud](https://github.com/EduIDE/EduIDE-Cloud) | The control plane. Kubernetes operator and REST service that create and manage sessions. |
| [EduIDE-Landing-Page](https://github.com/EduIDE/EduIDE-Landing-Page) | Where users pick an environment and launch a session. |
| [EduIDE-Helm](https://github.com/EduIDE/EduIDE-Helm) | The Helm charts. How you install EduIDE on a cluster. |
| [EduIDE-deployment](https://github.com/EduIDE/EduIDE-deployment) | The TUM installations: environment configuration and deployment workflows. |
| [Docs](https://github.com/EduIDE/Docs) | The documentation site. |
| [theia-scale-tests](https://github.com/EduIDE/theia-scale-tests) | End-to-end and scalability tests. |

Supporting components: [scorpio](https://github.com/EduIDE/scorpio) (Artemis
integration extension), [EduIDE-data-bridge](https://github.com/EduIDE/EduIDE-data-bridge)
(runtime data injection), [EduIDE-shared-cache](https://github.com/EduIDE/EduIDE-shared-cache)
(shared Gradle and Bazel build cache),
[workspace-garbage-collector](https://github.com/EduIDE/workspace-garbage-collector)
(reclaims abandoned workspace storage).

## Running it yourself

```bash
helm install eduide oci://ghcr.io/eduide/charts/eduide --version <version>
```

See the [administrator documentation](https://eduide.github.io/Docs/admins/)
for cluster prerequisites and configuration.

---

EduIDE is developed at the
[Applied Education Technologies](https://ase.cit.tum.de/) group, TUM.
It began as a fork of [Eclipse Theia Cloud](https://github.com/eclipse-theia/theia-cloud)
and [Theia IDE](https://github.com/eclipse-theia/theia-ide).
