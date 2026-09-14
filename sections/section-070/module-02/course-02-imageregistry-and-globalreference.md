# Part 2: imageRegistry and globalReference

## Data the Kubernetes API does not have

"Reject images not built for `linux`." "Reject images whose author label is missing." "Reject images larger than 500MB."

No `apiCall` can answer any of those, because the Kubernetes API server does not know what is inside a container image. That information lives in the registry, in the image's manifest and config blob.

An `imageRegistry` context entry fetches it, during admission:

```yaml
context:
  - name: imageData
    imageRegistry:
      reference: "{{ request.object.spec.containers[0].image }}"
```

`reference` is an image reference, and it is normally a variable rather than a literal — the whole point is to inspect whatever image this particular request is trying to run.

## What the result contains

The bound object has eight top-level keys. Rather than take that on faith, ask for them:

```yaml
context:
  - name: imageData
    imageRegistry:
      reference: "{{ request.object.spec.containers[0].image }}"
  - name: keys
    variable:
      jmesPath: "keys(imageData)"
```

```text
PROBE keys: ["resolvedImage","configData","identifier","image","manifest","manifestList","registry","repository"]
```

The four you will use most:

| Field | Holds |
| :--- | :--- |
| `registry` | the registry host — `ghcr.io` |
| `repository` | the path within it — `kyverno/test-verify-image` |
| `resolvedImage` | the reference with the tag resolved to a digest |
| `configData` | the image config: `os`, `architecture`, `config.Labels`, `config.User`, and more |

`manifest` and `manifestList` carry the raw OCI structures, which is where you go for layer sizes or platform lists.

> [!TIP]
> **Try it — read an image's real metadata mid-admission**
>
> ```sh
> kubectl apply -f image-metadata-probe.yaml
> kubectl run p3 --image=ghcr.io/kyverno/test-verify-image:signed --restart=Never
> ```
>
> Expect something like:
>
> ```text
> probe3:
>   show: 'PROBE: ["ghcr.io","kyverno/test-verify-image","ghcr.io/kyverno/test-verify-image@sha256:b31bfb4d0213f254d361e0079deaaebefa4f82ba7aa76ef82e90b4935ad5b105","linux","amd64"]'
> ```
>
> None of that came from the Pod spec you submitted — the spec said
> `ghcr.io/kyverno/test-verify-image:signed` and nothing else. The registry host,
> the repository path, the resolved digest, the OS and the architecture were all
> fetched from `ghcr.io` while the request was being admitted.

Note `resolvedImage`: the tag has become a digest. That is the same resolution Section 060's `mutateDigest` performs, available here as data rather than as a mutation — which is how you write a rule that *reasons about* the digest without rewriting the Pod.

An architecture check then reads naturally:

```yaml
validate:
  message: "Images must be built for linux."
  deny:
    conditions:
      all:
        - key: "{{ imageData.configData.os }}"
          operator: NotEquals
          value: "linux"
```

> [!NOTE]
> This is a **network call inside the admission path**, to a host outside your cluster. Everything that implies is true: it adds latency to every matching request, it can time out, and it fails when the registry is unreachable or the image is private and Kyverno holds no credentials for it. Scope the `match` block tightly, and think about what should happen when the registry is down — a rule that cannot fetch data cannot evaluate, and with `failurePolicy: Fail` that means the request is rejected. Section 060 covers registry credentials for private images.

## globalReference: paying for a lookup once

Every context entry runs on every matching request. For an `apiCall` against your own API server that is usually acceptable. For a lookup that is expensive, external, or identical for every request — an allowlist fetched from an external service, say — repeating it thousands of times a day is waste.

A **`GlobalContextEntry`** is a cluster-scoped object that performs a lookup on a schedule and caches the result. Policies then read the cache instead of performing the lookup:

```yaml
context:
  - name: allowed
    globalReference:
      name: allowed-registries-cache
      jmesPath: "..."
```

The `GlobalContextEntry` itself holds either a `kubernetesResource` (watch a resource type and cache it) or an `apiCall` (call something on an interval and cache the response). The distinction matters: `kubernetesResource` keeps a live cache of cluster objects, while `apiCall` is the escape hatch for anything outside the API server — including services that need a POST, which a policy-level `apiCall` cannot do.

The trade is freshness. A cached value is by definition not the current one, and a rule that must see this instant's state — Module 1's "how many Pods are in this namespace right now" — cannot use a cache without changing what it means. Reach for `globalReference` when the data changes slowly and is read often; keep `apiCall` when the answer must be current.

> [!NOTE]
> `GlobalContextEntry` is cluster-scoped, so it is not something an application team adds for themselves — creating one is a cluster-level action, and its cached contents are readable by any policy. Like the ConfigMap in Part 1, it is part of the policy trust boundary, and for the same reason: whoever controls the cached data controls what the rules using it decide.

## Choosing between the four

| Entry type | Reach for it when |
| :--- | :--- |
| `apiCall` | the answer is live cluster state and must be current |
| `configMap` | the data is operational, changes more often than the policy, and lives in the cluster |
| `variable` | you are naming an intermediate value or reusing an expression |
| `imageRegistry` | the answer is inside a container image |
| `globalReference` | the lookup is expensive or external, and a slightly stale answer is acceptable |

The question that usually settles it: *where does this fact actually live?* Cluster state, operational config, the image itself, or somewhere outside entirely. Each has an entry type, and using `apiCall` for all of them is how policies end up slow.

> [!WARNING]
> **Common pitfalls**
>
> - **Using `imageRegistry` on a broad `match`.** Every matching Pod triggers an external network call during admission.
> - **Assuming the registry lookup uses the node's image-pull credentials.** It does not; Kyverno needs its own access for private registries.
> - **Reaching a nested `imageRegistry` field directly in a `message`.** It rendered empty on v1.19.1 — bind it through a `variable` entry first.
> - **Caching something that must be current.** A `globalReference` answers with what it last fetched, which is the wrong tool for a live quota check.
> - **Treating cached or ConfigMap-sourced data as trusted.** Whoever can write it can change what your rules decide.

## Section recap

`imageRegistry` fetches data the Kubernetes API cannot know, binding an eight-field object whose `registry`, `repository`, `resolvedImage`, and `configData` cover most needs — at the cost of an external network call inside the admission path. `globalReference` reads a `GlobalContextEntry`, which performs an expensive or external lookup on a schedule and caches it, trading freshness for cost. Between the five entry types, the deciding question is where the fact you need actually lives.
