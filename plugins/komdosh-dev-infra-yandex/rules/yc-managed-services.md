# Yandex Cloud Managed Services

Prefer managed services over self-hosting stateful systems — YC operates the control plane, backups, and failover you'd otherwise build. The rules below are the production-readiness bar for the ones this suite touches most.

## Managed Service for Kubernetes

- **Regional master for production.** A regional master spreads the control plane across three zones and survives a zone loss; a zonal master is a single-zone SPOF — acceptable only for dev.
- **Node groups with autoscaling** (`yandex_kubernetes_node_group` + cluster autoscaler): set min/max, spread across zones, size the node type to the workloads' requests. Separate node groups for system vs application vs stateful workloads where isolation matters.
- **Network policy** enabled (Calico) so in-cluster traffic is default-deny (pairs with the kubernetes plugin's `rules/k8s-security.md`).
- **Node SA** with only `container-registry.images.puller` (+ required node roles), never editor/admin.
- **Version + upgrade policy**: pin the k8s version; use a maintenance window; test upgrades in a lower env first.
- The cluster's API endpoint follows `rules/yc-security.md` (private or CIDR-restricted). This plugin provisions the cluster; the workloads on it are the kubernetes/argocd plugins' domain.

## Managed Service for PostgreSQL (and MySQL/Redis/OpenSearch)

- **HA topology**: ≥2 hosts across ≥2 zones for production; a single-host cluster has no failover. Put the primary and replica in different zones.
- **Backups**: automated backups enabled with an explicit **retention** window and a known **backup window**; verify point-in-time recovery is available. A managed DB without a stated backup/retention policy is a finding.
- **`prevent_destroy = true`** on the cluster (terraform plugin `rules/terraform-state-safety.md`) — a `forces replacement` on `yandex_mdb_postgresql_cluster` destroys the data. Watch the plan for it.
- **Access**: private (no public IP), reachable only from the app subnets/SG; credentials from Lockbox; TLS enforced.
- **Sizing & disk**: right-size the resource preset and disk; enable disk autoscaling where supported so you don't wake up to a full volume.

## Managed Service for Kafka

- Multi-broker across zones for durability; set replication factor ≥3 and `min.insync.replicas` appropriately for production topics.
- Access via SG from producers/consumers only; SASL/TLS on; credentials from Lockbox.
- (If the estate uses Redpanda instead of Managed Kafka, the same durability/access principles apply; provisioning is generic Terraform via `terraform-author`.)

## Container Registry

- One registry per environment or a shared registry with per-folder IAM; nodes pull with `images.puller`, CI pushes with `images.pusher` — distinct SAs.
- Enable image scanning; set a lifecycle policy to expire old/untagged images.
- Images referenced by **digest** downstream (kubernetes plugin `rules/k8s-manifests.md`).

## Object Storage

- Buckets **private** by default; public access is an explicit, justified exception (never for state or data buckets).
- **Encryption** (KMS) and, for critical buckets, **versioning** + a lifecycle policy.
- Static access keys for the bucket are secrets (Lockbox / CI), never committed.

## Cross-cutting

Every managed service: private access, encryption at rest (KMS), secrets in Lockbox, a dedicated least-privilege SA, HA across zones for prod, and a stated backup/retention where it holds data. `yc-auditor` checks exactly these; `verify-yc-resources` is the fast preflight.
