# Yandex Cloud Managed Services

Prefer managed over self-hosted for stateful systems — YC operates the control plane, backups, and failover you would otherwise build. This is the production-readiness bar.

## Managed Kubernetes

- **Regional master in production.** It spreads the control plane across three zones and survives a zone loss; **a zonal master is a single-zone SPOF** — dev only.
- Node groups with autoscaling, spread across zones, sized to the workloads' requests; separate groups where system, application, and stateful workloads need isolation.
- **Network policy enabled** so in-cluster traffic is default-deny.
- **Node SA limited to the image-puller and node roles** — never editor or admin.
- Pin the version, use a maintenance window, and test upgrades in a lower environment first.

This plugin provisions the cluster; what runs inside it belongs to `komdosh-dev-infra-k8s`.

## Managed PostgreSQL / MySQL / Redis / OpenSearch

- **HA: at least two hosts across two zones in production.** A single-host cluster has no failover.
- **Automated backups with an explicit retention and backup window**, and point-in-time recovery verified. A managed database with no stated backup policy is a finding.
- **`prevent_destroy = true` on the cluster.** A `forces replacement` on an MDB cluster destroys the data — watch every plan for it.
- Private, no public IP, reachable only from the app subnets; credentials from Lockbox; TLS enforced.
- Right-size the preset and disk, and **enable disk autoscaling where supported** so a full volume isn't a 3am page.

## Managed Kafka

Multi-broker across zones, replication factor ≥3 with `min.insync.replicas` set for production topics. SG-restricted to producers and consumers, SASL/TLS on, credentials from Lockbox.

## Container Registry

Distinct service accounts for pull and push. Image scanning on, a lifecycle policy expiring untagged images, and **images referenced downstream by digest**.

## Object Storage

**Private by default** — public access is an explicit, justified exception, and never for a state or data bucket. KMS encryption, versioning plus lifecycle on critical buckets, and static access keys treated as secrets.

## Cross-cutting

Every managed service: private access · encryption at rest · secrets in Lockbox · a dedicated least-privilege SA · HA across zones in prod · a stated backup and retention where it holds data. `verify-yc-resources` is the fast preflight; `iac-reviewer` is the deep pass.
