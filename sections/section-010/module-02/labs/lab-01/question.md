# Question

Kyverno is installed. Write one `ClusterPolicy` named `deployment-guardrails` with `validationFailureAction: Enforce` and `background: false`. It applies to Deployments in the namespace `shop` and uses `validate.deny` in three rules:

1. **Replica cap:** reject a Deployment with more than 5 replicas.
2. **Tier label:** reject a Deployment whose `tier` label is not one of `frontend`, `backend` or `batch` (a missing label is also rejected).
3. **Registries:** reject a Deployment if any container image does not start with `ghcr.io/` or `registry.example.com/`. Use `foreach` so that every container is tested.
