# Yandex Cloud Security

The blast radius is the folder or cloud: an over-privileged service account or a committed SA key is a full-tenant credential.

## IAM — scoped, least privilege

- **Scope bindings to the folder or a single resource**, never the cloud, unless cloud-wide reach is genuinely needed.
- **Prefer `..._iam_member`** (one role, one member — composable and individually revertible) over `..._iam_binding`, which is authoritative for a role and **silently drops other members**, and far over `..._iam_policy`, which is authoritative for the folder and **can lock you out**.
- **No primitive `admin` or `editor` on a service account.** A node SA gets the image-puller and node roles; a CI SA gets exactly what it provisions; a backup SA gets storage write. Wildcard or admin on an SA is a finding.
- **One service account per workload.** Reusing one across the cluster, CI, and apps means a single leak grants everything.

## Service-account keys — the highest-value secret

A static key is a long-lived credential. **Prefer keyless**: a bound service account via instance metadata for workloads, a short-lived IAM token or OIDC federation for CI.

Where a key is unavoidable it is created out-of-band and written only to Lockbox or CI secrets — **never a `.tf`, `.tfvars`, or committed `*-key.json`**. A committed SA key is a rotate-immediately incident.

## Secrets and encryption

Secrets live in **Lockbox**, read at runtime by an identity holding `lockbox.payloadViewer` on that specific secret — not in env literals, variable defaults, or ConfigMaps. **KMS** encrypts everything at rest: managed-service disks, buckets, Lockbox itself, and the state bucket (which holds resource secrets in cleartext).

## Network — default deny, private by default

Security groups start closed; add explicit ingress only, from known CIDRs or SGs. **`0.0.0.0/0` on an admin or database port (22, 5432, 6379, 9200, 8443) is a BLOCKER**; on 443 for a genuine public endpoint it is expected — confirm the intent.

**No public IP** on managed databases, internal services, or nodes. Reach private resources through the VPC, a bastion, or an internal load balancer; egress through NAT. Put the Managed K8s API on a private endpoint, or restrict its authorized CIDRs.

## Audit

Enable **Audit Trails** on the folder so IAM changes, resource mutations, and data-plane events are logged somewhere durable. Human access is federated with MFA; static keys are for machines, and even then keyless wins.
