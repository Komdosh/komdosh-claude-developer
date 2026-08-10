# Kubernetes Security — Pod Security Standards (Restricted)

The baseline is the **restricted** Pod Security Standard. Every workload runs as an unprivileged, locked-down process unless there is a documented, reviewed reason not to. A container that can escalate is a cluster compromise waiting for a CVE.

## The securityContext every pod needs

```yaml
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 10001
    runAsGroup: 10001
    fsGroup: 10001
    seccompProfile:
      type: RuntimeDefault
  containers:
    - name: app
      securityContext:
        allowPrivilegeEscalation: false
        readOnlyRootFilesystem: true
        privileged: false
        capabilities:
          drop: ["ALL"]           # drop everything; add back only what's proven necessary
```

- **`runAsNonRoot: true`** + a non-zero `runAsUser` — never run as root. The image must support a non-root UID (writable dirs, no privileged ports).
- **`readOnlyRootFilesystem: true`** — mount `emptyDir` for the few paths that need writes (`/tmp`, caches). A writable root FS lets an attacker drop binaries.
- **`allowPrivilegeEscalation: false`** and **`capabilities.drop: ["ALL"]`** — the two highest-value controls. Add a capability back only with a comment explaining why (e.g. `NET_BIND_SERVICE` for a port <1024, though prefer a high port).
- **`seccompProfile: RuntimeDefault`** — filters dangerous syscalls.

## Host isolation — forbidden by default

- No `hostNetwork`, `hostPID`, `hostIPC` — these break the container/host boundary.
- No `hostPath` volumes except for genuine node agents (DaemonSets), and then read-only and narrowly scoped.
- No `privileged: true` containers. A privileged container is root on the node.

## Service accounts and RBAC

- **`automountServiceAccountToken: false`** unless the workload actually calls the Kubernetes API. A mounted token is a credential an exploited pod can use.
- One **dedicated ServiceAccount** per workload — never the namespace `default`.
- **RBAC least privilege** — Roles grant the specific verbs/resources needed, namespaced, never `cluster-admin`, never `*` verbs on `*` resources. A wildcard Role is a finding.

## Network policy — default deny

- Namespaces carrying workloads have a **default-deny** NetworkPolicy (deny all ingress/egress), with explicit allow rules for the traffic that must flow. Without one, any compromised pod can reach every other pod.
- Egress is restricted too — a workload that only talks to its DB and one API shouldn't have open egress to the internet.

## Secrets

- Consumed from a secret store (External Secrets / Sealed Secrets / SOPS / Vault), never a plaintext committed `Secret` (base64 ≠ encryption — see infra-core `rules/secrets-hygiene.md`).
- Prefer mounting secrets as files over env vars (env is readable via `/proc` and crash dumps); set restrictive file modes.
- Never bake a secret into an image or a ConfigMap.

## Images and supply chain

- Immutable digests; pull from a trusted registry. Prefer minimal/distroless base images — fewer packages, smaller attack surface.
- Where the cluster enforces it, sign images and require verification (admission policy). At minimum, scan images for known CVEs in CI.
