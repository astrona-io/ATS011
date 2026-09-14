# Part 2: Cloning Resources and `synchronize`

## When the content already exists somewhere else

`generate.data` is the right tool when the generated resource's content is fixed and small enough to write directly into a policy — a default-deny `NetworkPolicy` is a good example, because its content never varies from namespace to namespace. But plenty of real generation use cases are the opposite: a shared TLS CA bundle, a registry pull secret, a `ConfigMap` full of cluster-wide settings — content that already exists as a real object somewhere in the cluster, that you want *copied*, not retyped into a policy as a second source of truth that can quietly drift from the original.

`generate.clone` is Kyverno's answer: instead of `data`, you point at an existing **source** resource, and Kyverno copies it.

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: clone-shared-ca
spec:
  rules:
    - name: clone-shared-ca-configmap
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

`generate.data` and `generate.clone` are mutually exclusive ways of answering the same question — "what goes in the generated resource?" — so a single `generate` block uses one or the other, never both. Everything else about the rule (`match`, `exclude`, `generate.apiVersion`/`kind`/`name`/`namespace`) is identical to Part 1; only the source of content changes.

`clone.namespace` and `clone.name` identify the **source** object to copy — here, a `ConfigMap` named `shared-ca` that already lives in a central `platform-config` namespace, presumably maintained by the platform team. `generate.namespace` (note: not `clone.namespace`) is still the *destination* — the newly created namespace, exactly as in Part 1.

## synchronize: true — what it actually does, verified against a live cluster

`synchronize` is the single field in this whole module most likely to be tested from memory incorrectly, so nothing here is assumed — every claim below was checked directly against Kyverno running on a real `kind` cluster while building this lab, not read once in documentation and taken on faith.

**1. Editing the source propagates to every existing clone, automatically, with no new trigger event.**

```bash
kubectl create ns team-billing
sleep 5
kubectl get configmap shared-ca -n team-billing -o jsonpath='{.data.ca.crt}'
# PLATFORM-ROOT-CA-V1

kubectl patch configmap shared-ca -n platform-config \
  --type merge -p '{"data":{"ca.crt":"PLATFORM-ROOT-CA-V2"}}'
sleep 5
kubectl get configmap shared-ca -n team-billing -o jsonpath='{.data.ca.crt}'
# PLATFORM-ROOT-CA-V2
```

Nobody touched `team-billing`. The clone updated on its own, purely because the source changed. This is the behavior that makes `synchronize: true` valuable for something like a shared CA bundle: rotate it once, centrally, and every namespace's copy follows without a second action.

The playground does not ship a source ConfigMap, so create one yourself — that is part of the point, since `clone` needs a real object to copy from and you should see where it lives.

> [!TIP]
> **Try it — rotate the source, watch the copy follow**
>
> ```sh
> kubectl create ns platform-config
> kubectl create configmap shared-ca -n platform-config --from-literal=ca.crt=PLATFORM-ROOT-CA-V1
> kubectl apply -f clone-policy.yaml
>
> kubectl create ns team-billing
> kubectl get cm shared-ca -n team-billing -o jsonpath='{.data.ca\.crt}'
>
> kubectl patch cm shared-ca -n platform-config --type merge -p '{"data":{"ca.crt":"PLATFORM-ROOT-CA-V2"}}'
> kubectl get cm shared-ca -n team-billing -o jsonpath='{.data.ca\.crt}'
> ```
>
> Expect something like:
>
> ```text
> PLATFORM-ROOT-CA-V1
> PLATFORM-ROOT-CA-V2
> ```
>
> Two reads of the same object in `team-billing`, different answers, and nothing
> ran against `team-billing` in between. Give each read a few seconds; both the
> initial clone and the propagation are asynchronous.

**2. Editing the clone directly gets silently reverted back to match the source.** `synchronize: true` doesn't just mean "stays up to date" in one direction — it means Kyverno treats the clone as *its* resource, not a starting point you're now free to diverge from:

```bash
kubectl patch configmap shared-ca -n team-billing \
  --type merge -p '{"data":{"ca.crt":"TAMPERED"}}'
sleep 3
kubectl get configmap shared-ca -n team-billing -o jsonpath='{.data.ca.crt}'
# PLATFORM-ROOT-CA-V2      <- reverted, not "TAMPERED"
```

The API server accepts the patch — Kyverno isn't blocking the write with an admission rule, there's no `validate` in play here — but within a few seconds the background controller notices the drift and overwrites it back to match the source. If your policy actually wants namespace owners to be able to customize their copy, `synchronize: true` is the wrong setting; that's precisely the tradeoff it makes.

**3. Deleting the clone directly gets it recreated.** This is the cleanest, most deterministic way to *prove* `synchronize: true` is doing anything, and the one this section's capstone lab grades on:

```bash
kubectl delete configmap shared-ca -n team-billing
sleep 5
kubectl get configmap shared-ca -n team-billing
# NAME        DATA   AGE
# shared-ca   1      4s      <- recreated, not gone
```

Both of those are worth doing back to back on the clone you already have, because
together they are the proof that `synchronize: true` is actively maintaining the
object rather than having copied it once.

> [!TIP]
> **Try it — tamper with the clone, then delete it**
>
> ```sh
> kubectl patch cm shared-ca -n team-billing --type merge -p '{"data":{"ca.crt":"TAMPERED"}}'
> kubectl get cm shared-ca -n team-billing -o jsonpath='{.data.ca\.crt}'
>
> kubectl delete cm shared-ca -n team-billing
> kubectl get cm shared-ca -n team-billing
> ```
>
> Expect something like:
>
> ```text
> configmap/shared-ca patched
> PLATFORM-ROOT-CA-V2
>
> configmap "shared-ca" deleted
> NAME        DATA   AGE
> shared-ca   1      8s
> ```
>
> The patch was accepted by the API server and then undone; the delete succeeded
> and the object came back seconds later with a fresh `AGE`. Nothing blocked
> either write — Kyverno is not validating here, it is reconciling afterwards.

> [!NOTE]
> A natural but incorrect assumption is that `synchronize: true` works by attaching a Kubernetes `ownerReference` from the clone to the trigger Namespace, so that deleting the Namespace triggers ordinary Kubernetes garbage collection of the clone. Inspecting a generated clone's `metadata.ownerReferences` on a live cluster shows it is empty — Kyverno tracks the link between trigger, source, and generated resource entirely through its own `generate.kyverno.io/*` labels and an internal `UpdateRequest` object, never through `ownerReferences`. Kyverno's documentation does state that `synchronize: true` also causes the generated resource to be deleted if the trigger itself is deleted or stops matching — but with a Namespace as the trigger and the clone living *inside* that same Namespace, this specific mechanism is impossible to isolate: deleting the Namespace wipes out everything inside it via Kubernetes' own namespace-deletion controller regardless of Kyverno, regardless of `synchronize`, and even if no policy existed at all. What you *can* observe directly and unambiguously — reversion of direct edits, and recreation after a direct delete — is `synchronize: true` actively keeping the clone alive and correct while the Namespace it lives in is still around.

With `synchronize: false` — the default if you omit the field — none of the three behaviors above happen. The clone is copied exactly once, at the moment the trigger Namespace is created, and from then on it is a completely independent object: the source can change freely with no effect on it, a direct edit sticks, and a direct delete stays deleted. Which one you want depends entirely on the resource: a default resource quota that teams are expected to *tune themselves* is a `synchronize: false` (or plain `data`) case; a shared CA bundle or a set of registry credentials that must never drift from the platform team's version is exactly what `synchronize: true` is for.

## Choosing between the two

You can check the `ownerReferences` claim from the note above on the clone you
just recreated — `kubectl get cm shared-ca -n team-billing -o jsonpath='{.metadata.ownerReferences}'`
comes back as an empty list, which is why deleting the clone is recreated by
Kyverno rather than garbage-collected by Kubernetes.

The decision between the two settings is a question about who owns the copy. A
default `ResourceQuota` that teams are expected to tune for themselves wants
`synchronize: false` (or a plain `data` rule): copied once, then theirs. A CA
bundle or a set of registry credentials that must never drift from the platform
team's version wants `synchronize: true`: Kyverno's object, in their namespace,
maintained on their behalf and reverted if they touch it.

Getting that choice wrong is not a subtle failure. With `synchronize: true` on a
resource teams were meant to customise, their edits silently disappear a few
seconds after they make them — which is an unusually frustrating thing to debug
from the team's side, because nothing rejected their change.
