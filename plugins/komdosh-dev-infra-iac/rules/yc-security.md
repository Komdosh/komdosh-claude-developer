# Yandex Cloud Security

Least privilege, secrets in Lockbox, encryption on, network default-deny. YC's blast radius is the folder/cloud; an over-privileged service account or a committed SA key is a full-tenant credential.

## IAM — least privilege, always scoped

- **Scope bindings to the folder** (or a single resource), never the cloud, unless the role genuinely needs cloud-wide reach. `yandex_resourcemanager_folder_iam_member` (one role, one member — composable) is safer than `..._iam_binding` (authoritative for a role, silently drops other members) and far safer than `..._iam_policy` (authoritative for the whole folder — can lock you out).
- **No primitive `admin`/`editor` on a service account.** Grant the specific service role: a k8s node SA gets `container-registry.images.puller` + the node roles; a CI SA gets exactly the resource roles it provisions; a backup SA gets storage write only. Wildcard/admin on an SA is a finding.
- **One service account per workload/purpose.** Don't reuse one SA across the cluster, CI, and apps — a leak of one shouldn't grant everything.
- Prefer `iam_member` per (role, SA) so each grant is individually reviewable and revertible.

## Service-account keys — the highest-value secret

- A `yandex_iam_service_account_key` / `..._static_access_key` is a **long-lived credential**. Prefer keyless auth:
  - workloads on VMs / Managed K8s → a **bound service account** via instance metadata (no key);
  - CI → a short-lived IAM token, or federation (OIDC/SAML), over a static key.
- When a key is unavoidable, it is created out-of-band or written only to **Lockbox / CI secrets** — never to a `.tf`, a `.tfvars`, or a committed `*-key.json` (infra-core `rules/secrets-hygiene.md`). A committed SA key is a rotate-immediately incident.

## Secrets — Lockbox + KMS

- Application and infra secrets live in **Lockbox** (`yandex_lockbox_secret`), read at runtime by an identity with `lockbox.payloadViewer` on that secret. Not in env literals, not in Terraform variables with defaults, not in ConfigMaps.
- **KMS** (`yandex_kms_symmetric_key`) encrypts data at rest — managed-service disks, Object Storage buckets, Lockbox itself. Enable encryption on anything holding data.
- Terraform state holds resource secrets in cleartext → encrypt the Object Storage state bucket and restrict who can read it.

## Network — default deny, private by default

- **Security groups** start closed: no rule = no traffic. Add explicit ingress only for required ports from known CIDRs/SGs. `0.0.0.0/0` on an admin/DB port (22, 5432, 6379, 9200, 8443) is a BLOCKER; on 443 for a genuine public endpoint it's expected — confirm intent.
- **No public IP** on managed databases, internal services, or nodes unless a specific public role demands it. Reach private resources through the VPC / a bastion / an internal load balancer; egress via NAT.
- Put the Managed K8s API endpoint on a private endpoint where the workflow allows; if public, restrict authorized CIDRs.

## Audit and org policy

- Enable **Audit Trails** on the folder/cloud so IAM changes, resource mutations, and data-plane events are logged to Object Storage / a SIEM.
- Apply org-level constraints where available (allowed regions, key expiry, MFA for humans). Human access is federated (SSO) with MFA; static keys are for machines only, and even then keyless is preferred.
