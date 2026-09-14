# Part 2: ImageValidatingPolicy and DeletingPolicy

## ImageValidatingPolicy

`ImageValidatingPolicy` replaces `rules[].verifyImages`, and its schema shows the same decomposition the rest of the family got — the fields that were nested inside a `verifyImages` entry became top-level `spec` fields:

| `ImageValidatingPolicy` field | What it holds | Section 060 counterpart |
| :--- | :--- | :--- |
| `images` | named CEL expressions selecting which image references to check | `imageReferences` |
| `matchImageReferences` | glob-style reference matching | `imageReferences` / `skipImageReferences` |
| `attestors` *(required)* | named trust material, each `cosign` or `notary` | `attestors` |
| `attestations` | named attestation requirements | `attestations` |
| `validations` *(required)* | CEL expressions over the verification results | — |
| `credentials` | registry credentials | `imageRegistryCredentials` |
| `validationActions` | `Deny` / `Audit` / `Warn` | `failureAction` |

Two changes are worth dwelling on.

**Attestors are named, not positional.** Section 060 Part 1 spent real effort on reading `.attestors[1].entries[0]` out of an error message, because the classic structure identifies trust material by index. Here each attestor carries a `name`, and `validations` expressions refer to it by that name. A rule with three signers reads as three names rather than three indices, and a failure names the one that mattered.

**`notary` sits alongside `cosign`.** The classic rule's attestor entries were Sigstore-shaped — keys, certificates, keyless identities. `ImageValidatingPolicy` makes the verification *backend* an explicit choice between `cosign` and `notary`, which is the shape you need if your organisation signs with Notation rather than Cosign.

The `images` field is the other structural change: instead of a list of glob strings, it is a list of **named CEL expressions** that select image references out of the resource. That means the set of images a policy examines can be computed — from the containers, the init containers, an annotation — rather than matched by pattern alone.

> [!NOTE]
> `ImageValidatingPolicy` is described here from its resource schema, not from a captured run. Verifying it end to end needs a signed image and a reachable registry, and this module's cluster time went to the two kinds below and in Part 1. The field names, types, and which are required are accurate as read from the CRD on v1.19.1; the runtime behaviour is what you should confirm before depending on it.

## DeletingPolicy

`DeletingPolicy` is the kind that Section 100's deprecation warning pointed at every time you applied a `ClusterCleanupPolicy`:

```text
Warning: kyverno.io/v2 ClusterCleanupPolicy is deprecated and will be removed in a
future release; migrate to DeletingPolicy (policies.kyverno.io)
```

It keeps the model exactly and changes the expression language:

```yaml
apiVersion: policies.kyverno.io/v1
kind: DeletingPolicy
metadata:
  name: sweep-ephemeral
spec:
  schedule: "* * * * *"
  matchConstraints:
    resourceRules:
      - apiGroups: [""]
        apiVersions: ["v1"]
        operations: ["CREATE", "UPDATE"]
        resources: ["pods"]
  conditions:
    - name: only-ephemeral
      expression: "has(object.metadata.labels) && object.metadata.labels['lifecycle'] == 'ephemeral'"
```

Set that beside Section 100's `ClusterCleanupPolicy` and the correspondence is one-to-one: `schedule` is unchanged, `match` became `matchConstraints`, and `conditions` went from JMESPath `key`/`operator`/`value` triples to **named CEL expressions**. `deletionPropagationPolicy` carries over unchanged.

One difference matters when writing the conditions. The classic form evaluated against **`target`**, because there is no admission request during a sweep. Here the expressions read **`object`** — the same name a `ValidatingPolicy` uses — which is more consistent across the family but will catch you out if you are translating an existing cleanup policy line by line.

And the `has()` guard is required for exactly the reason Module 1 Part 2 established: a Pod with no labels at all would otherwise make the expression error rather than evaluate to false.

> [!TIP]
> **Try it — a CEL-native sweep that discriminates**
>
> ```sh
> kubectl apply -f cleanup-rbac.yaml
> kubectl apply -f deleting-policy.yaml
> kubectl get deletingpolicy
>
> kubectl create ns dp-demo
> kubectl -n dp-demo run doomed --image=nginx:1.27 --restart=Never --labels=lifecycle=ephemeral
> kubectl -n dp-demo run keeper --image=nginx:1.27 --restart=Never --labels=lifecycle=permanent
> kubectl get pods -n dp-demo
> ```
>
> Expect something like — after waiting for a minute boundary:
>
> ```text
> NAME              AGE   READY
> sweep-ephemeral   5s    true
>
> NAME     READY   STATUS    RESTARTS   AGE
> keeper   1/1     Running   0          64s
> ```
>
> `doomed` was swept and `keeper` spared, discriminated by the CEL condition.
> The RBAC grant is the **same one** Section 100 required — a `ClusterRole`
> labelled `rbac.kyverno.io/aggregate-to-cleanup-controller: "true"` granting
> `delete` on `pods`. The new kind did not change who does the deleting, so it
> did not change what that controller needs permission to do.

> [!NOTE]
> One observable difference from `ClusterCleanupPolicy`: `status` came back empty on the `DeletingPolicy` after a sweep had demonstrably run, where the classic kind reported `lastExecutionTime` on a cron boundary. If you used that field to confirm a schedule was firing — Section 100 suggested exactly that — you will need to confirm by observing the resources instead.

## The whole map

| Classic | CEL-native | Namespaced form |
| :--- | :--- | :--- |
| `ClusterPolicy` → `rules[].validate` | `ValidatingPolicy` | `NamespacedValidatingPolicy` |
| `ClusterPolicy` → `rules[].mutate` | `MutatingPolicy` | `NamespacedMutatingPolicy` |
| `ClusterPolicy` → `rules[].generate` | `GeneratingPolicy` | `NamespacedGeneratingPolicy` |
| `ClusterPolicy` → `rules[].verifyImages` | `ImageValidatingPolicy` | `NamespacedImageValidatingPolicy` |
| `ClusterCleanupPolicy` / `CleanupPolicy` | `DeletingPolicy` | `NamespacedDeletingPolicy` |
| `PolicyException` (`kyverno.io`) | `PolicyException` (`policies.kyverno.io`) | — |

Reading an unfamiliar policy, the `apiVersion` tells you which world you are in before you read a single rule: `kyverno.io/v1` or `kyverno.io/v2` is classic, `policies.kyverno.io/*` is CEL-native.

## What this means for the exam, and for your cluster

For the KCA, keep authoring classic policies. The Writing Policies competencies are framed in classic terms, and `ClusterPolicy` remains fully functional on v1.19.1 — the deprecation warnings signpost direction, not removal. What this module buys you is the ability to *read* a CEL-native policy and say what it does, which is a fair thing to be asked.

For a real cluster, the honest position is that this family is newer and still moving — `MutatingPolicy` served at both `v1alpha1` (deprecated) and `v1` on the same cluster, and two of the five kinds here could not be exercised end to end in the time available. Adopt deliberately, verify on your own cluster, and do not assume a field behaves as its classic counterpart did just because the name carried over. The `target` → `object` change in `DeletingPolicy` conditions is a small, concrete example of exactly that.

> [!WARNING]
> **Common pitfalls**
>
> - **Assuming a co-located pair survives the split.** A `MutatingPolicy` and the `ValidatingPolicy` depending on it are separate objects; deleting one leaves the other enforcing against resources nothing fixes any more.
> - **Translating `target` to `target` in a `DeletingPolicy`.** Its conditions read `object`.
> - **Copying an `apiVersion` from older material.** `policies.kyverno.io/v1alpha1` already warns in favour of `v1`.
> - **Expecting `status.lastExecutionTime` on a `DeletingPolicy`.** It was empty after a verified sweep.
> - **Expecting the new cleanup kind to need less RBAC.** Same controller, same aggregating `ClusterRole` requirement.

## Section recap

`ImageValidatingPolicy` decomposes a `verifyImages` entry into top-level fields, names its attestors instead of indexing them, and makes `cosign` versus `notary` an explicit backend choice. `DeletingPolicy` is `ClusterCleanupPolicy` with CEL conditions — same cron schedule, same cleanup controller, same RBAC requirement — differing in that its expressions read `object` rather than `target`, and that it reported no `status` after a verified sweep. The `apiVersion` alone tells you which family a policy belongs to.
