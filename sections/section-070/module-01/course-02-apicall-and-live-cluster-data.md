# Part 2: context.apiCall & Live Cluster Data

## The problem built-in variables can't solve

Part 1's variables all came from the admission request itself — the resource, its previous version, who submitted it. None of that tells you anything about the rest of the cluster. "Does this namespace already have too many Pods?" isn't a question about the Pod being created; it's a question about every *other* Pod that already exists. Answering it requires the rule to reach out and ask the Kubernetes API, at the exact moment it runs, for data it wasn't handed.

`context.apiCall` is that mechanism: a rule-level block that performs an HTTP request — to the Kubernetes API server itself, or to any other JSON web service — and stores the (optionally reshaped) response in a named variable, available to the rest of the rule exactly like any other `{{ }}` reference.

## Where context lives

`context` is a field on each individual rule — `spec.rules[].context` — not on the policy as a whole. This was confirmed directly against a live cluster: `kubectl explain clusterpolicy.spec.context` returns `error: field "context" does not exist`, while `kubectl explain clusterpolicy.spec.rules.context` resolves and describes exactly the shape below. If two rules in the same policy both need the same live data, each rule needs its own `context` entry — there's no policy-wide place to define it once in the `kyverno.io/v1` `ClusterPolicy`/`Policy` API.

## The exact shape of `apiCall`

Straight from the cluster's own CRD schema (`kubectl explain clusterpolicy.spec.rules.context.apiCall --recursive`), the fields are:

| Field | Purpose |
| --- | --- |
| `urlPath` | A path on the Kubernetes API server itself, e.g. `/api/v1/namespaces/{{request.namespace}}/pods`. Mutually exclusive with `service`. |
| `service` | Call an *external* URL instead of the Kubernetes API: `service.url` (required), plus optional `service.caBundle` and `service.headers`. |
| `method` | `GET` (default) or `POST` — no other verbs are accepted. |
| `data` | For `POST`, a list of `{key, value}` pairs sent as the request body. |
| `jmesPath` | A JMESPath expression applied to the raw response, so the context variable holds only the shaped value you actually need, not the entire payload. |
| `default` | A fallback value used if the API call itself fails — covered in detail below. |

A minimal, real example — count every Pod in the namespace of the resource currently being admitted:

```yaml
context:
  - name: nsPodCount
    apiCall:
      urlPath: "/api/v1/namespaces/{{request.namespace}}/pods"
      jmesPath: "items | length(@)"
```

`urlPath` itself accepts `{{ }}` variables (it's not `match`/`exclude` — this is rule-body territory), so `{{request.namespace}}` is substituted with the actual namespace of the Pod being created before the request is ever sent. `jmesPath: "items | length(@)"` takes the Kubernetes `PodList` response — whose Pods live under an `items` array — and collapses it to a single number: how many Pods currently exist in that namespace. That number is now available as `{{nsPodCount}}` anywhere in the rest of the rule.

## A second mechanism: the `variable` context type

`apiCall` isn't the only thing a `context` entry can hold. The same schema also exposes a `variable` type, which runs a JMESPath expression against data Kyverno *already has* — no network call — and gives the result a name:

```yaml
context:
  - name: podName
    variable:
      jmesPath: "request.object.metadata.name"
```

This looks similar to just writing `{{ request.object.metadata.name }}` inline wherever you need it, and for a single use, it is equivalent. The difference matters once a rule uses the same derived value more than once, or wants to give a long JMESPath expression a short, readable name up front — the same reason you'd assign a variable in any programming language rather than repeat an expression. The capstone lab combines this with `apiCall` in one policy, precisely to show both mechanisms working side by side.

## Building and proving a real quota check

Here is the complete policy this module's lab is built around, verified end-to-end against a live `kind` cluster. It rejects a new Pod if its namespace already has 3 or more Pods — a real, dynamic decision, not a number anyone hardcoded per namespace:

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: pod-quota-per-namespace
spec:
  validationFailureAction: Enforce
  background: false
  rules:
    - name: limit-pods-per-namespace
      match:
        any:
          - resources:
              kinds:
                - Pod
              operations:
                - CREATE
      exclude:
        any:
          - resources:
              namespaces:
                - kube-system
                - kyverno
                - local-path-storage
      context:
        - name: nsPodCount
          apiCall:
            urlPath: "/api/v1/namespaces/{{request.namespace}}/pods"
            jmesPath: "items | length(@)"
      validate:
        message: >-
          Namespace "{{request.namespace}}" already has {{nsPodCount}}
          Pod(s); the limit is 3 per namespace.
        deny:
          conditions:
            any:
              - key: "{{nsPodCount}}"
                operator: GreaterThanOrEquals
                value: 3
```

> [!NOTE]
> `operations: [CREATE]` is not optional here, and this was discovered the hard way rather than anticipated. Without it, `match` also applies this rule to DELETE requests — and a `deny` condition checking "does this namespace already have 3+ Pods" is still true right up until the *last* Pod over the limit is actually removed. That means the very Pods that push a namespace over quota can never be deleted through the normal API, because every delete attempt re-runs the same `apiCall`, sees the count is still at or over the limit, and denies the delete too. Deleting the whole namespace then hangs indefinitely: Kubernetes' namespace controller keeps retrying to delete the Pods inside it and keeps getting denied by the very policy that put them over quota, a genuine self-inflicted deadlock that was reproduced live — `kubectl get ns team-b` sat in `Terminating` with a `NamespaceDeletionContentFailure` condition quoting this exact policy's own denial message, until the `ClusterPolicy` itself was deleted. Scoping the rule to `operations: [CREATE]` avoids this entirely: the quota still governs whether a *new* Pod can be admitted, but it never has an opinion about a DELETE, so a namespace at or over its limit can always be cleaned up normally.

> [!NOTE]
> The `exclude` block isn't decoration. A stock `kind` cluster's `kube-system` namespace already runs around 8 Pods (CoreDNS, kube-proxy, the CNI, etc.) — comfortably over this lab's limit of 3. Without excluding it, the very first time any control-plane Pod needed to be rescheduled, this policy would block its recreation, since a plain `match.resources.kinds: [Pod]` with no `exclude` genuinely does apply cluster-wide, control plane included. The same reasoning applies to Kyverno's own namespace: a rule that can block Kyverno's own controller Pods from restarting is one bad `kubectl apply` away from locking you out of admission control entirely.

Two namespaces prove the count is live and per-namespace rather than global or
hardcoded. The playground already runs three Pods in `team-a` — seeded at startup,
before any policy existed — so `team-a` is at the limit the moment you apply the
policy, while a namespace you create yourself starts at zero.

> [!TIP]
> **Try it — one policy, two different answers**
>
> ```sh
> kubectl apply -f quota-policy.yaml
> kubectl get pods -n team-a --no-headers | wc -l
>
> kubectl -n team-a run overflow --image=nginx:1.27 --restart=Never
>
> kubectl create ns team-b
> kubectl -n team-b run first --image=nginx:1.27 --restart=Never
> ```
>
> Expect something like:
>
> ```text
> 3
>
> pod-quota-per-namespace:
>   limit-pods-per-namespace: Namespace "team-a" already has 3 Pod(s); the limit is 3 per namespace.
>
> namespace/team-b created
> pod/first created
> ```
>
> The same unchanged policy rejected a Pod in one namespace and admitted an
> identical Pod in another, seconds apart. Nothing in the YAML mentions `team-a`
> or `team-b`; the count in the message was fetched from the API server during
> each request.

Keep adding Pods to `team-b` and it will reject the fourth with the same message
naming `team-b` — the rule re-reads the count on every single admission, so the
answer changes as the cluster changes. That is the whole point of `apiCall`, and
it is also its cost: every matching request now carries an extra API round-trip
inside the admission path.

## RBAC: what the admission controller is allowed to read

`context.apiCall` runs as the Kyverno admission-controller's own service account — it inherits whatever that ServiceAccount is bound to, the same way any other client of the Kubernetes API would. This was checked directly:

> [!TIP]
> **Try it — ask the API server what Kyverno is allowed to read**
>
> ```sh
> kubectl auth can-i list pods --as=system:serviceaccount:kyverno:kyverno-admission-controller -A
> kubectl auth can-i list secrets --as=system:serviceaccount:kyverno:kyverno-admission-controller -A
> ```
>
> Expect something like:
>
> ```text
> yes
> no
> ```
>
> `--as` impersonates the service account rather than asking about you, which is
> the only useful question here — your own permissions have nothing to do with
> whether an `apiCall` will work. The split between those two answers is exactly
> the boundary of the built-in `view` role, and it predicts which `urlPath`
> values will succeed before you write the policy.

The stock Kyverno install already binds the admission-controller's ServiceAccount to the built-in Kubernetes `view` ClusterRole (via the `kyverno:admission-controller:view` `ClusterRoleBinding`). `view` grants read access (`get`/`list`/`watch`) to almost every built-in resource type — Pods included — which is why the quota policy above needed **zero extra RBAC** to work. This is a genuinely different situation from Section 040's `mutateExistingOnPolicyUpdate`, where the *background controller* needed a hand-granted `ClusterRole` (aggregated via the `rbac.kyverno.io/aggregate-to-background-controller` label) because `view` only grants read access, and mutating existing Pods needs `update`/`patch` too. A read-only `apiCall` against a resource type covered by `view` needs nothing extra; only if you point `apiCall` at something `view` deliberately excludes — Kubernetes `Secrets` being the obvious example — or if you need write verbs, would you reach for the same aggregation pattern Section 040 used.

> [!NOTE]
> This was verified, not assumed. Pointing the same policy's `apiCall` at `/api/v1/namespaces/{{request.namespace}}/secrets` instead of `/pods` — a resource type `view` does *not* grant read access to — reproduced the exact same failure text `context.apiCall` produces for any failed call (next section). Two completely different causes — a genuinely nonexistent URL path, and a real RBAC denial against Secrets — both collapsed to the identical error string `permission denied: unknown`. Kyverno does not distinguish "the API returned 404" from "the API returned 403" in the error it surfaces; both simply mean the `apiCall` didn't produce data.

## What happens when the API call fails

This is the part worth verifying rather than guessing, because the answer determines whether a broken `apiCall` fails your cluster open or closed. With no `default` set, a failed `apiCall` — bad RBAC, an invalid `urlPath`, a service that's down — causes the *variable substitution itself* to fail, which in turn fails the condition evaluation that depends on it. Under `Enforce`, Kyverno's own webhook logging showed this surfaces as a blocked admission request, not a silently-skipped rule:

```
error: failed to create configmap: admission webhook "validate.kyverno.svc-fail" denied the request:

resource ConfigMap/quota-test/test-cm-2 was blocked due to the following policies

secrets-apicall-test:
  secret-call: 'failed to check deny conditions: failed to substitute variables in
    condition key: failed to resolve secretCount at path : failed to fetch data for
    APICall: failed to GET resource with raw url: /api/v1/namespaces/quota-test/secrets:
    permission denied: unknown'
```

In other words: **a failing `context.apiCall` fails closed, not open.** A rule that depends on live data it cannot fetch does not quietly let the resource through — it errors, and in `Enforce` mode that error becomes a denial. This matters operationally: a typo'd `urlPath` or an RBAC regression in a quota-style policy like the one above doesn't just break the quota check, it starts rejecting *every* matching resource, which is exactly the kind of outage you want to know about before it happens in production rather than discover live.

`default` is the escape hatch. Adding `default: 0` to the same failing `apiCall` was verified to change the outcome completely — the ConfigMap that was previously blocked was admitted instead, because the failed lookup resolved to the fallback value (`0`) rather than raising an error:

```yaml
context:
  - name: secretCount
    apiCall:
      urlPath: "/api/v1/namespaces/{{request.namespace}}/secrets"
      jmesPath: "items | length(@)"
      default: 0
```

Whether you want that fail-open behavior is a real design decision, not a default you should leave unconsidered: for a quota-style limit, failing open on `default: 0` means a broken `apiCall` silently stops enforcing the quota at all rather than blocking every admission — arguably the safer choice for availability, arguably the wrong choice if the quota exists for a hard resource-exhaustion reason. Know which one you're choosing.

## Background scans see live data too

One more thing worth confirming rather than assuming: does `context.apiCall` even work during a **background scan** (Section 030) — evaluating a resource that already exists, with no live admission request driving it? It does, and `{{request.namespace}}` resolves correctly in that mode as well. Setting the same quota policy's `background: true` and lowering its threshold so two pre-existing Pods would fail produced exactly the failing `PolicyReport` entries you'd expect:

```
result: fail
rule: limit-pods-per-namespace
scope: { kind: Pod, name: seed-a }
```

Both `seed-a` and `seed-b` — Pods that existed before the policy was ever applied — were correctly evaluated against a freshly-fetched live count of their own namespace, confirming `apiCall` isn't limited to admission-time evaluation; a background scan re-runs it too, against the resource's own `request.namespace` context, each time the scan executes.
