# Solution Guide: Generation Rules Capstone

One `ClusterPolicy`, two rules — one `generate.data` rule carried over from the module lab, and one new `generate.clone` rule with `synchronize: true`.

---

## Step 1: Write the policy

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: generate-namespace-baseline
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
                - platform-config
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

    - name: clone-shared-ca
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
                - platform-config
      generate:
        apiVersion: v1
        kind: ConfigMap
        name: shared-ca
        namespace: "{{request.object.metadata.name}}"
        synchronize: true
        clone:
          namespace: platform-config
          name: shared-ca
```

```bash
kubectl apply -f policy.yaml
kubectl get clusterpolicy generate-namespace-baseline
```

---

## Step 2: What `synchronize: true` actually guarantees (verified empirically)

This is the part of Kyverno's exam material people get wrong from memory, so here is what was directly observed against a real cluster while building this lab — not the assumed behavior.

**1. Editing the source propagates to every clone, one-way, automatically.**

```bash
kubectl create ns team-billing
sleep 5
kubectl get configmap shared-ca -n team-billing -o jsonpath='{.data.ca.crt}'
# PLATFORM-ROOT-CA-V1

kubectl patch configmap shared-ca -n platform-config --type merge -p '{"data":{"ca.crt":"PLATFORM-ROOT-CA-V2"}}'
sleep 5
kubectl get configmap shared-ca -n team-billing -o jsonpath='{.data.ca.crt}'
# PLATFORM-ROOT-CA-V2
```

The clone updated on its own. Nobody touched `team-billing`.

**2. Editing the clone directly gets reverted back to match the source.** `synchronize: true` treats the clone as something Kyverno owns, not a one-time copy you're now free to diverge from:

```bash
kubectl patch configmap shared-ca -n team-billing --type merge -p '{"data":{"ca.crt":"TAMPERED"}}'
sleep 3
kubectl get configmap shared-ca -n team-billing -o jsonpath='{.data.ca.crt}'
# PLATFORM-ROOT-CA-V2   <- reverted, not "TAMPERED"
```

**3. Deleting the clone directly gets it recreated.** This is the cleanest, most deterministic proof of ownership, and the one the grading script relies on:

```bash
kubectl delete configmap shared-ca -n team-billing
sleep 5
kubectl get configmap shared-ca -n team-billing
# shared-ca   1   4s   <- back, recreated from the source
```

> [!NOTE]
> A common assumption is that `synchronize: true` works by attaching a Kubernetes `ownerReference` from the generated clone to the trigger Namespace, so deleting the Namespace triggers standard garbage collection of the clone. That assumption does not hold up: inspecting a generated clone's `metadata.ownerReferences` in this lab shows it is empty — Kyverno links a generated resource back to its trigger and source purely through its own `generate.kyverno.io/*` labels and an internal `UpdateRequest` object, never through `ownerReferences`. Kyverno's own documentation states that with `synchronize: true`, deleting or un-matching the trigger resource makes Kyverno delete the generated resource itself. In this lab's specific setup, though, that mechanism is impossible to observe in isolation: the trigger *is* the Namespace, and the generated `ConfigMap` lives *inside* that same Namespace, so the moment you delete the Namespace, Kubernetes' own namespace-deletion controller wipes out everything inside it — Kyverno or not, `synchronize` or not. What you can observe directly, and what this lab's grading checks, is the behavior while the Namespace is still alive: `synchronize: true` is what makes Kyverno actively re-create or repair the clone in place, on its own, without anyone touching the Namespace at all.

With `synchronize: false` (the default), none of the three behaviors above happen: the clone is copied once at Namespace-creation time and from then on lives an entirely independent life — source edits never propagate, direct edits to the clone stick, and a deleted clone stays deleted.

---

## Step 3: Prove it end-to-end

```bash
kubectl create ns team-billing
# both default-deny-ingress and shared-ca appear within a few seconds

kubectl get networkpolicy,configmap -n team-billing
# NAME                                             POD-SELECTOR   AGE
# networkpolicy.networking.k8s.io/default-deny-ingress   <none>   6s
#
# NAME                    DATA   AGE
# configmap/shared-ca     1      6s
# configmap/kube-root-ca.crt   1   6s
```

Clean up your own scratch Namespace (`kubectl delete ns team-billing`); the grading script creates and tears down its own test Namespace, and additionally mutates and deletes the clone inside it to verify `synchronize: true` end to end — so don't be surprised if the source ConfigMap's value has changed by the time you look at it again after a graded run.
