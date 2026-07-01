# CLAUDE.md — komdosh-dev-infra-yandex

Yandex Cloud provisioning and audit on top of `komdosh-dev-infra-core`, pairing with `komdosh-dev-infra-terraform`. One domain: build YC infrastructure that is least-privilege, secrets-in-Lockbox, encrypted, and highly available — and audit what's there — always as reviewable Terraform, never by applying from here.

## What it adds

| Piece | Purpose |
|---|---|
| [`/yc-provision <resource>`](commands/yc-provision.md) | Author YC Terraform (network, Managed K8s, Managed PG/Kafka, Lockbox, IAM) via `yc-provisioner`. |
| [`/yc-audit`](commands/yc-audit.md) | Security + reliability audit via `yc-auditor`. |
| [`/yc-context`](commands/yc-context.md) | Resolve and print cloud/folder/zone, services, auth model, state via `discover-yc-context`. |
| [`yc-provisioner`](agents/yc-provisioner.md) | Writes secure-and-HA-by-default YC Terraform; delegates generic HCL to `terraform-author`; never applies. |
| [`yc-auditor`](agents/yc-auditor.md) | Read-only IAM/secrets/network/reliability audit, BLOCKER/WARNING/INFO with blast radius. |
| [`discover-yc-context`](skills/discover-yc-context/SKILL.md) | Resolves folder/zone/services/auth/state → descriptor. |
| [`verify-yc-resources`](skills/verify-yc-resources/SKILL.md) | Fast security+reliability preflight over YC Terraform. |
| `rules/*.md` | Three convention documents, imported via `@rules/...` below. |

## Big picture

This plugin owns **YC resource semantics**; the terraform plugin owns the **generic HCL shape**. `yc-provisioner` writes YC resources following both rule sets and delegates module scaffolding, variable typing, and plan review to `terraform-author`/`terraform-reviewer`/`verify-plan-safety`. `yc-auditor` audits the YC-specific security and reliability properties; generic plan/state mechanics stay with `terraform-reviewer`. Neither agent applies — provisioning produces a reviewable plan a human approves.

The default posture is secure and HA: regional Managed K8s masters, HA managed databases with backups and `prevent_destroy`, least-privilege single-purpose IAM service accounts (no admin/editor, keyless over static keys), Lockbox for secrets, KMS for encryption at rest, default-deny security groups, and private access for data/internal resources. `yc-auditor` and `verify-yc-resources` check exactly these; a committed SA key or an `editor`-on-a-service-account binding is a full-folder credential and always a BLOCKER.

Because the YC provider evolves (the Object Storage backend key names changed recently, for example), the agents resolve current provider arguments and versions deliberately — Terraform registry / MCP / `yandex.cloud` docs — rather than from memory.

## Conventions imported as rules

- **`yc-terraform.md`** — provider auth precedence (keyless > IAM token > key file), `cloud_id`/`folder_id`/`zone` as variables never literals, the Object Storage `s3` state backend (with the version-sensitive flags), VPC + per-zone subnets + default-deny security groups, naming/labels, and blast-radius root splitting.
- **`yc-security.md`** — least-privilege folder-scoped IAM (`iam_member` over `binding` over `policy`; no admin/editor/wildcard on SAs), SA keys as the highest-value secret (keyless preferred; never in git), Lockbox + KMS, network default-deny and private-by-default, Audit Trails and federated human access.
- **`yc-managed-services.md`** — the production bar for Managed K8s (regional master, autoscaling node groups, network policy, node SA scope), Managed PostgreSQL/Kafka/Redis (HA across zones, backups+retention, `prevent_destroy`, private+TLS), Container Registry (distinct pusher/puller SAs, scanning, digest refs), and Object Storage (private, KMS, versioning).
- **`yc-data-residency.md`** — 152-FZ localization made concrete for YC: Russian personal data recorded and stored in `ru-central1` (backups/replicas in-region too), PII-at-rest controls (KMS, Lockbox, private access, least-priv IAM, Audit Trails), and the load-bearing 152-FZ-vs-GDPR divergence — 152-FZ pulls RU data into Russia while GDPR restricts moving EU-subject data to Russia, so EU and RU personal data must be jurisdiction-partitioned, not commingled in one `ru-central1` store. Specialises infra-core's `rules/pii-data-protection.md`; engineering obligations, not legal advice.

## Relationship to the rest of the suite

- **Generic Terraform** → `komdosh-dev-infra-terraform` (shape, plan safety, state discipline).
- **The cluster's workloads** → `komdosh-dev-infra-kubernetes` (this plugin provisions the Managed K8s cluster; that plugin runs workloads on it).
- **Delivery onto the cluster** → `komdosh-dev-infra-argocd`.
- **Secrets** → `secrets-sentinel` (infra-core) sweeps for SA-key and secret leaks.

## When editing this plugin

- New agent → `agents/<name>.md` (`name`, `model` alias, `description` with triggers; read-only agents set `disallowedTools`).
- New skill → `skills/<name>/SKILL.md` (`user-invocable: false` + read-only `allowed-tools`).
- New rule → add the file **and** its `@rules/<file>.md` import below.
- Nothing to build; run `tools/lint-marketplace.sh` from the repo root.

@rules/yc-terraform.md
@rules/yc-security.md
@rules/yc-managed-services.md
@rules/yc-data-residency.md
