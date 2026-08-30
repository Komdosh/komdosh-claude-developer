# Kubernetes Security — Restricted Pod Security Standards

Every workload runs unprivileged and locked down unless there is a documented, reviewed reason otherwise. **A container that can escalate is a cluster compromise waiting for a CVE.**

## The securityContext every pod needs

Pod level: `runAsNonRoot: true` with a non-zero `runAsUser`/`runAsGroup`/`fsGroup`, and `seccompProfile: RuntimeDefault`.
Container level: `allowPrivilegeEscalation: false`, `readOnlyRootFilesystem: true`, `privileged: false`, `capabilities.drop: ["ALL"]`.

- **`runAsNonRoot` requires the image to support it** — a writable home, no privileged ports. That is why `rules/local-dev.md` in the Spring suite mandates a non-root UID in the Dockerfile.
- **`readOnlyRootFilesystem`** with `emptyDir` for the few writable paths. A writable root lets an attacker drop binaries.
- **`allowPrivilegeEscalation: false` and dropping ALL capabilities are the two highest-value controls.** Add a capability back only with a comment explaining why.

## Host isolation — forbidden by default

No `hostNetwork`, `hostPID`, or `hostIPC` — they break the container/host boundary. No `hostPath` except for genuine node agents, read-only and narrowly scoped. **No `privileged: true`: that is root on the node.**

## Service accounts and RBAC

**`automountServiceAccountToken: false`** unless the workload actually calls the API — a mounted token is a credential an exploited pod can use. A dedicated ServiceAccount per workload, never the namespace `default`. Roles grant specific verbs on specific resources, namespaced; **a wildcard Role is a finding, and `cluster-admin` is never the answer.**

## Network policy — default deny

Every workload namespace has a default-deny NetworkPolicy with explicit allows. **Without one, any compromised pod can reach every other pod.** Restrict egress too — a service that talks to its database and one API has no business with open internet egress.

## Secrets

From a secret store, never a committed plaintext `Secret`. **Prefer file mounts over env vars** — environment is readable through `/proc` and lands in crash dumps. Never bake a secret into an image or a ConfigMap.

## Images

Immutable digests from a trusted registry; minimal or distroless bases. Sign and verify by admission policy where the cluster supports it; scan for CVEs in CI at minimum.
