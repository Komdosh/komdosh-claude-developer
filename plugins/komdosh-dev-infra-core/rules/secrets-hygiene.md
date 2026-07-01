# Secrets Hygiene

A secret is any value whose disclosure enables access you didn't intend: passwords, API tokens, private keys, connection strings with credentials, service-account key files, TLS private keys, webhook signing secrets. The rule is singular and absolute: **a secret never lands in git in a form anyone can read.**

## Where secrets are allowed to live

| Layer | Correct home | Never |
|---|---|---|
| Kubernetes | External Secrets Operator (pulling from Vault / cloud secret store), Sealed Secrets, or SOPS-encrypted manifests | A `Secret` with plaintext `stringData`, or base64 `data`, committed to git (base64 is encoding, not encryption) |
| Terraform | A secret manager data source (Vault, cloud KMS/secret store) read at plan time; injected via a CI secret; marked `sensitive` | A literal in `.tf`, a committed `.tfvars`, or a `default` on a secret variable |
| ArgoCD | The above, referenced by the Application; ArgoCD Vault Plugin or a secret-management operator | A plaintext value in the Application manifest or the tracked values file |
| CI/CD | The platform's secret store (GitHub Actions secrets, GitLab CI masked+protected variables, Vault) | `env:` literals, `echo`ed secrets, secrets in build logs |
| Cloud (Yandex, AWS, …) | Lockbox / KMS / Secrets Manager, referenced by IAM identity | Committed service-account key JSON; secrets in resource metadata/labels |

## Non-negotiable rules

1. **Base64 is not encryption.** A committed k8s `Secret` is plaintext to anyone with repo read access. Treat `data:`/`stringData:` in a tracked file as a leak.
2. **`sensitive = true` hides console output, not state.** Terraform still writes the value to state in cleartext. Keep secrets out of state where possible (read them at apply time from a secret store) and always encrypt the backend.
3. **A secret in a plan/diff is a leak.** `terraform plan` and `argocd app diff` can print secret values. Never paste raw plan/diff output containing secrets into chat, PRs, tickets, or logs. Redact before sharing.
4. **Rotate on exposure, don't just delete.** Removing a committed secret in a later commit leaves it in history. The only remediation is to rotate the credential; scrubbing history is secondary.
5. **Service-account keys are the highest-value secret.** A committed cloud SA key JSON is a full credential. Prefer keyless auth (workload identity, instance metadata, federated OIDC) over long-lived keys; when a key is unavoidable, it lives only in a secret store.
6. **`.gitignore` is a safety net, not a control.** Ignore `*.tfvars`, `*-key.json`, `*.pem`, `kubeconfig`, `.env` — but never rely on ignore rules alone; a secret store is the actual control.

## When you find a secret in code

Treat it as an incident, in this order:

1. **Stop** — do not commit, do not include it in a diff you share.
2. **Report** it (file:line, what kind of secret) — the `secrets-sentinel` agent produces this report; a human decides.
3. **Recommend rotation** of the exposed credential as the primary fix, and migration to a secret store as the durable one.
4. **Never** print the secret value back in your report — reference it by location and type only.
