# Secrets Hygiene

A secret is any value whose disclosure grants access you didn't intend. The rule is absolute: **a secret never lands in git in a form anyone can read.**

## Where secrets live

| Layer | Correct home | Never |
|---|---|---|
| Kubernetes | External Secrets Operator, Sealed Secrets, or SOPS-encrypted manifests | A committed `Secret` with `data:` or `stringData:` |
| Terraform | A secret-manager data source read at plan time, or CI injection; marked `sensitive` | A `.tf` literal, a committed `.tfvars`, or a `default` on a secret variable |
| ArgoCD | The above, referenced by the Application; Vault Plugin or a secret operator | A plaintext value in the Application or its tracked values |
| CI/CD | The platform's secret store | `env:` literals, `echo`ed secrets, secrets in build logs |
| Cloud | Lockbox / KMS / Secrets Manager, referenced by IAM identity | A committed service-account key JSON; secrets in resource metadata |

## Non-negotiable

1. **Base64 is encoding, not encryption.** A committed k8s `Secret` is plaintext to anyone with repo read access.
2. **`sensitive = true` hides console output, not state.** Terraform still writes the value to state in cleartext — read secrets at apply time from a store, and always encrypt the backend.
3. **A secret in a plan or diff is a leak.** Redact before pasting plan/diff output anywhere.
4. **Rotate on exposure; deletion is not remediation.** A secret removed in a later commit still lives in history. Rotation is the fix; scrubbing history is secondary.
5. **A service-account key is the highest-value secret.** Prefer keyless auth (workload identity, instance metadata, federated OIDC); where a key is unavoidable it lives only in a secret store.
6. **`.gitignore` is a safety net, not a control.** Ignore `*.tfvars`, `*-key.json`, `*.pem`, `kubeconfig`, `.env` — but the secret store is the actual control.

## On finding one

Stop · report `file:line` and the secret **type** · recommend rotation first and migration to a store second · **never print the value back**.
