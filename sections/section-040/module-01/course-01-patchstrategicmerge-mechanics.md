# Part 1: patchStrategicMerge and Ordering

## A patch, not a pattern

A `mutate` rule's job is to change the resource, not judge it. The most common way to describe that change is `mutate.patchStrategicMerge`: a fragment of the resource's own shape, which Kyverno merges into the incoming object before it's persisted.

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: default-pod-baseline
spec:
  rules:
    - name: inject-pod-defaults
      match:
        any:
          - resources:
              kinds:
                - Pod
      mutate:
        patchStrategicMerge:
          metadata:
            labels:
              managed-by: platform
```

Apply this and run a plain Pod with no labels of its own. The thing to look at is
not whether the Pod was accepted — it obviously was — but what the cluster now
believes the Pod says.

> [!TIP]
> **Try it — the object in etcd is not the object you sent**
>
> ```sh
> kubectl run plain-pod --image=nginx --restart=Never
> kubectl get pod plain-pod -o jsonpath='{.metadata.labels}'
> ```
>
> Expect something like:
>
> ```text
> pod/plain-pod created
> {"managed-by":"platform","run":"plain-pod"}
> ```
>
> You never typed `managed-by`. (`run=plain-pod` is `kubectl run`'s own doing,
> not Kyverno's.) The label was added on the way in, and nothing told the
> requester it had happened.

The label is there in the persisted object — not just accepted, *added*. This is the fundamental difference from `validate`: nothing about the requester's original manifest demanded this label, and nothing rejected the request either. The object that lands in etcd is not the object that was submitted.

## Why "strategic merge," and why it matters for lists

The word "strategic" is doing real work in that field name. A naive JSON merge patch treats every list as an opaque blob: if your patch supplies a `containers` array, that array *replaces* the incoming resource's `containers` array wholesale, or merges element-by-element by list *position* (index 0 patches index 0, index 1 patches index 1, and so on) — exactly the same position-based behavior Section 010 warned about for `validate.pattern` against a list.

Kubernetes' strategic merge patch format exists specifically to fix this for its own built-in types. It knows, from each API type's own generated schema, which field in a list item acts as a *merge key* — for a Pod's `spec.containers`, that key is `name`. A strategic merge patch can say "find the container named `sidecar` and patch just this field on it," instead of "whatever is sitting at index 1, patch this field on it." Kyverno's `patchStrategicMerge` builds directly on this mechanism, which is exactly why it's the tool of choice for touching a specific, named element deep inside a list — a sidecar container, a specific volume — without having to reconstruct the entire list yourself.

## Reaching every element with the `(name)` anchor

Merging by key is only useful if you tell Kyverno *which* key value to merge against — and often, as with our `managed-by` label example, you don't want one specific container, you want *all of them*, however many the Pod happens to have. That's what the `(name)` anchor syntax is for:

```yaml
mutate:
  patchStrategicMerge:
    spec:
      containers:
        - (name): "*"
          imagePullPolicy: IfNotPresent
```

Wrapping `name` in parentheses turns it into an anchor: "apply this fragment to every list element whose `name` matches this wildcard" — and `*` matches everything. Test it against a two-container Pod, neither container setting `imagePullPolicy` itself:

> [!TIP]
> **Try it — one fragment, every container**
>
> ```sh
> kubectl apply -f - <<'EOF'
> apiVersion: v1
> kind: Pod
> metadata: {name: two-c}
> spec:
>   containers:
>     - {name: app, image: nginx}
>     - {name: sidecar, image: busybox, command: ["sleep","3600"]}
> EOF
> kubectl get pod two-c -o jsonpath='{range .spec.containers[*]}{.name}={.imagePullPolicy}{"\n"}{end}'
> ```
>
> Expect something like:
>
> ```text
> app=IfNotPresent
> sidecar=IfNotPresent
> ```
>
> Both containers were patched from a fragment that named neither of them. `*`
> in the `(name)` anchor matched every element, and each one was merged into
> individually rather than the list being replaced.

Both containers were patched — the loop reached every element, the same way `foreach` did for `validate` in Section 010.

> [!NOTE]
> This was tested directly while building this course: dropping the `(name)` anchor and writing a plain list entry instead — `containers: [{ imagePullPolicy: IfNotPresent }]`, with no `name` field at all — does not quietly patch just the first container the way a `validate.pattern` would. Kyverno tries to strategic-merge that fragment using the container merge key (`name`), finds no container whose name matches the fragment's (empty) name, and *inserts* it as a brand new list entry — a new "container" with no `name` field at all. The API server then rejects the whole Pod outright: `The Pod "..." is invalid: spec.containers: Required value`. A missing anchor on a `patchStrategicMerge` list isn't a silent no-op the way a positional `validate.pattern` mismatch can be — it actively corrupts the resource being created. If you're patching a list with `patchStrategicMerge`, decide up front whether you mean "this one specific element" (name it directly) or "every element" (use the `(name)` anchor) — there is no default third option.

## What happens when the incoming value already conflicts

Here's a question the reference documentation doesn't always spell out plainly, and one worth answering by testing rather than guessing: if a Pod arrives *already* setting the field your mutate rule also sets — to something different — who wins?

```bash
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: conflict-pod
  labels:
    managed-by: team-x
spec:
  containers:
    - name: app
      image: nginx
      imagePullPolicy: Always
EOF

kubectl get pod conflict-pod -o jsonpath='{.metadata.labels}'
# {"managed-by":"platform"}
kubectl get pod conflict-pod -o jsonpath='{.spec.containers[0].imagePullPolicy}'
# IfNotPresent
```

The policy's values win, every time, for both fields. This was verified directly, not assumed. `patchStrategicMerge` has no "only if absent" mode for a scalar field — a strategic merge patch for a scalar key always *replaces* whatever is currently there with the patch's value. There's no ambiguity to resolve for a scalar the way there sometimes is for a list: your fragment names a field and a value, and that value is what ends up in the persisted object, full stop. If you actually want "set this only when it's missing," you need to gate the rule with a `precondition` that checks whether the field already exists (Section 020 covers preconditions in depth) — `patchStrategicMerge` alone always overwrites.

## The guarantee: every mutate rule runs before any validate rule

Section 010 built `validate` rules that require a `team` label. Now imagine a `mutate` rule injects that same label. Which one does the API server actually see acting on the request — does the missing label get caught by `validate` before the `mutate` rule ever gets a chance to add it?

It doesn't. Kyverno runs **every mutate rule on the cluster, across every `ClusterPolicy`, before it runs any validate rule** — this is a hard ordering guarantee, not an artifact of one policy happening to list its rules in a particular sequence. This was verified two ways while building this course: first with both rules in the *same* policy, then with the mutate rule and the validate rule split into two entirely separate `ClusterPolicy` objects, one deliberately named to sort alphabetically *after* the other (so if ordering were merely "policies run in creation or name order," the validate policy would have gone first and rejected the Pod):

```yaml
# aa-validate-policy (created FIRST here, sorts first alphabetically)
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: aa-validate-policy
spec:
  rules:
    - name: require-team-label
      match:
        any:
          - resources: { kinds: [Pod] }
      validate:
        message: "managed-by label is required"
        pattern:
          metadata:
            labels:
              managed-by: "?*"
---
# zz-mutate-policy (created SECOND here, sorts last alphabetically)
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: zz-mutate-policy
spec:
  rules:
    - name: inject-team-label
      match:
        any:
          - resources: { kinds: [Pod] }
      mutate:
        patchStrategicMerge:
          metadata:
            labels:
              managed-by: platform
```

```bash
kubectl run cross-policy-test --image=nginx --restart=Never
kubectl get pod cross-policy-test -o jsonpath='{.metadata.labels}'
# {"managed-by":"platform","run":"cross-policy-test"}
```

The Pod is admitted. `aa-validate-policy` never saw a Pod missing the label, because by the time any validate rule anywhere on the cluster runs, every mutate rule anywhere on the cluster has already finished and the object they collectively produced is what gets validated. This is exactly why real-world Kyverno setups often lean on a mutate rule to fill in a default *and* a validate rule to guarantee that default (or an explicit override) is present — the two rules aren't racing each other; the mutate rule always gets there first.

The cleanest way to see that ordering is to build it in two steps and watch the
same command change its answer. Apply only the validate policy first and submit a
Pod that cannot satisfy it; then add the mutate policy — deliberately named to
sort *after* the validate one — and submit an identical Pod.

> [!TIP]
> **Try it — the same Pod, rejected then admitted**
>
> ```sh
> kubectl apply -f aa-validate-policy.yaml
> kubectl run before-mutate --image=nginx --restart=Never
>
> kubectl apply -f zz-mutate-policy.yaml
> kubectl run cross-policy-test --image=nginx --restart=Never
> kubectl get pod cross-policy-test -o jsonpath='{.metadata.labels}'
> ```
>
> Expect something like:
>
> ```text
> aa-validate-policy:
>   require-managed-by-label: 'validation error: managed-by label is required. rule require-managed-by-label failed at path /metadata/labels/managed-by/'
>
> pod/cross-policy-test created
> {"managed-by":"platform","run":"cross-policy-test"}
> ```
>
> Nothing about the second Pod's manifest was different. The only change was a
> mutate rule existing somewhere on the cluster — in a policy whose name sorts
> *after* the validating one — and the validate rule stopped having anything to
> object to.

That is the ordering guarantee doing its work across policy boundaries, not
within a single policy's rule list. It is also the reason the mutate-plus-validate
pairing is such a common production shape: the mutate rule supplies the default,
the validate rule guarantees the field is present however it got there, and the
two never race.
