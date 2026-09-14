# Solution Guide: Data-Based Generation

This guide writes a `ClusterPolicy` with one `generate` rule: it triggers on `kind: Namespace`, and generates a literal `NetworkPolicy` manifest into every new Namespace.

---

## Step 1: Write the policy

Create `policy.yaml`:

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: generate-default-deny-netpol
spec:
  rules:
    - name: default-deny-ingress
      match:
        any:
          - resources:
              kinds:
                - Namespace
      exclude:
        any:
          - resources:
              namespaces:
                - kube-system
                - kube-public
                - kube-node-lease
                - kyverno
                - local-path-storage
      generate:
        apiVersion: networking.k8s.io/v1
        kind: NetworkPolicy
        name: default-deny-ingress
        namespace: "{{request.object.metadata.name}}"
        data:
          spec:
            podSelector: {}
            policyTypes:
              - Ingress
```

A few things worth naming explicitly:

- `match` targets `kind: Namespace` — a Namespace being *created* is the trigger event. `exclude` keeps the rule from firing against the cluster's own system namespaces, which you almost never want carrying your custom NetworkPolicies.
- `generate.namespace` uses `{{request.object.metadata.name}}` — that's the name of the Namespace that was just created, the same variable syntax Section 070 covers in depth. Without it, every generated NetworkPolicy would need a hardcoded target namespace, which defeats the entire point of a generate rule.
- `generate.data` is a literal manifest, indented exactly like the resource it produces. Whatever you write under `data` becomes the `spec` of the generated object, verbatim.

---

## Step 2: Apply it

```bash
kubectl apply -f policy.yaml
kubectl get clusterpolicy generate-default-deny-netpol
```

You should see `READY: True`. (The `kyverno.io/v1 ClusterPolicy is deprecated` warning is expected — safe to ignore, as in every prior section's lab.)

---

## Step 3: Prove a new Namespace gets the generated resource

```bash
kubectl create ns team-checkout
# namespace/team-checkout created

kubectl get networkpolicy -n team-checkout
# (empty at first -- generation runs through the background controller, give it a few seconds)

kubectl get networkpolicy -n team-checkout
# NAME                    POD-SELECTOR   AGE
# default-deny-ingress    <none>         4s

kubectl get networkpolicy default-deny-ingress -n team-checkout -o yaml
# spec:
#   podSelector: {}
#   policyTypes:
#   - Ingress
```

Nobody wrote that `NetworkPolicy` by hand — creating the Namespace was the only action taken, and Kyverno generated the rest. Clean up when you're done (`kubectl delete ns team-checkout`); the grading script creates and deletes its own test Namespace independently.
