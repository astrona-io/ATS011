# Part 2: Writing a validate.cel Rule Safely

Part 1 ended on an uncomfortable note: Kyverno type-checks your expression, tells you it is wrong, and installs it anyway. This part is about what happens next — the two failure modes that follow, both of which look like a working policy from the outside.

## The pitfall that will bite you first

CEL does not silently return null for a missing field. It raises an error, and under `Enforce` that error blocks the request. Write the ergonomic-looking version of the memory-limit rule:

```yaml
expression: "object.spec.containers.all(c, c.resources.limits['memory'] != '')"
```

and submit a Pod that sets no resources at all:

```bash
kubectl run noguard --image=nginx --restart=Never
# Error from server: admission webhook "validate.kyverno.svc-fail" denied the request:
#
# resource Pod/default/noguard was blocked due to the following policies
#
# no-has-guard:
#   check: 'expression ''object.spec.containers.all(c, c.resources.limits[''memory''] != '''')''
#     resulted in error: no such key: limits'
```

The Pod was rejected — but read the message. That is not your policy's `message` field; it is `resulted in error: no such key: limits`. The expression did not evaluate to `false`, it failed to evaluate, and the rule fell closed.

You were warned about this, and it is easy to miss. Part 1's checkpoint showed
Kyverno type-checking exactly this expression at apply time — `undefined field
'limits'`, with a caret at the offending offset — and creating the policy anyway.
The warning predicted this rejection precisely, and it scrolled past.


> [!WARNING]
> A CEL evaluation error under `Enforce` looks, from the outside, exactly like a policy working correctly: the non-compliant resource got rejected. It is only when a *compliant* resource that also happens to omit the optional field gets rejected — with a message no one on your team wrote — that anyone notices. Guard every optional field with `has()` before you index into it. The chain matters too: checking `has(c.resources.limits)` without first checking `has(c.resources)` errors on exactly the resources you were trying to be careful about.

The guarded version, evaluated left to right with `&&` short-circuiting:

```yaml
expression: "object.spec.containers.all(c, has(c.resources) && has(c.resources.limits) && 'memory' in c.resources.limits)"
```

## The same bug, one step worse: DELETE

There is a second, nastier face of this. A `match` block that names only `kinds: [Pod]` and says nothing about operations matches **every** operation — including `DELETE`. And on a DELETE, there is no incoming resource: `object` is null, and the resource being removed is in `oldObject`.

So the unguarded expression does not merely mis-handle odd Pods. It errors on every deletion:

```bash
kubectl delete pod fully-limited
# unguarded-cel:
#   check: 'expression ''object.spec.containers.all(c, c.resources.limits[''memory''] != '''')''
#     resulted in error: no such key: spec'
```

Read the key it could not find: `spec`, not `limits`. There was no object at all to look inside.

And here is the part that catches careful people: **`has()` does not save you from this.** Guarding the container fields is guarding the wrong thing — the failure happens one level up, on `object` itself, before any `has()` in your predicate ever runs. The fully-guarded expression fails identically:

> [!TIP]
> **Try it — a compliant Pod you cannot delete**
>
> ```sh
> kubectl create ns deltest
> kubectl run v1 -n deltest --image=nginx --restart=Never \
>   --overrides='{"spec":{"containers":[{"name":"v1","image":"nginx","resources":{"limits":{"memory":"64Mi"}}}]}}'
> kubectl delete pod v1 -n deltest
> ```
>
> Expect something like:
>
> ```text
> pod/v1 created
>
> guarded-no-ops:
>   check: 'expression ''variables.containers.all(c, has(c.resources) && has(c.resources.limits) && ''memory'' in c.resources.limits)'' resulted in error: composited variable "containers" fails to evaluate: no such key: spec'
> ```
>
> The Pod satisfies the rule — it was admitted without complaint — and it still
> cannot be deleted. Have `kubectl delete clusterpolicy --all` ready before you
> run this: while such a policy is applied, no Pod can be removed and any
> namespace containing one will hang in `Terminating`.

The `variables` entry — `object.spec.containers` — is evaluated first, and it is what breaks. A predicate that never gets reached cannot defend anything.

> [!WARNING]
> A CEL expression that assumes `object` exists can make Pods **undeletable**. Under `Enforce`, the evaluation error denies the DELETE request, and because the rule matches every Pod cluster-wide, nothing can be removed — a namespace containing such a Pod will sit in `Terminating` forever, since namespace deletion works by deleting its contents. This was hit while building this course, and it is considerably more disruptive than a Pod that fails to be created: a rejected CREATE is visible immediately to whoever ran the command, while a cluster that quietly cannot delete anything looks fine until something needs to scale down.
>
> The fix is to restrict the rule to the operations you actually mean, in `match`:
>
> ```yaml
> match:
>   any:
>     - resources:
>         kinds:
>           - Pod
>         operations:
>           - CREATE
>           - UPDATE
> ```
>
> With that in place the rule is never consulted on a DELETE, `object` is never null when the expression runs, and deletion works normally — verified on v1.19.1. Keep the `has()` guards as well: they defend against optional fields on resources that *are* present, which is a different problem with the same symptom. Treat `operations` as mandatory on any CEL rule that dereferences `object`, not as an optimisation.

Part 1 introduced the `variables` block and noted that entries are evaluated before any expression referencing them. That ordering is what the DELETE failure above demonstrates: the error names the *variable* as the thing that broke, because it is evaluated first and nothing in the `all()` body ever ran.

## The whole rule, end to end

Everything outside the `validate` block is the ordinary `ClusterPolicy` you have written since Section 010 — `match`, `validationFailureAction`, `background`. Only the innards of `validate` have changed.

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-memory-limits
spec:
  validationFailureAction: Enforce
  background: false
  rules:
    - name: check-memory-limits
      match:
        any:
          - resources:
              kinds:
                - Pod
      validate:
        cel:
          variables:
            - name: containers
              expression: "object.spec.containers"
          expressions:
            - expression: "variables.containers.all(c, has(c.resources) && has(c.resources.limits) && 'memory' in c.resources.limits)"
              message: "Every container must set spec.containers[].resources.limits.memory."
```

```bash
kubectl apply -f policy.yaml
# clusterpolicy.kyverno.io/require-memory-limits created

kubectl get clusterpolicy require-memory-limits
# NAME                    ADMISSION   BACKGROUND   READY   AGE   MESSAGE
# require-memory-limits   true        false        True    10s   Ready
```

The interesting test is a Pod where *one* container complies and another does not
— a single-container test would pass even against an expression that only ever
inspects `containers[0]`.

> [!TIP]
> **Try it — `all()` means all of them**
>
> ```sh
> kubectl apply -f - <<'EOF'
> apiVersion: v1
> kind: Pod
> metadata: {name: half-limited}
> spec:
>   containers:
>     - name: app
>       image: nginx
>       resources: {limits: {memory: "64Mi"}}
>     - name: sidecar
>       image: busybox
>       command: ["sleep","3600"]
> EOF
>
> kubectl apply -f - <<'EOF'
> apiVersion: v1
> kind: Pod
> metadata: {name: fully-limited}
> spec:
>   containers:
>     - name: app
>       image: nginx
>       resources: {limits: {memory: "64Mi"}}
>     - name: sidecar
>       image: busybox
>       command: ["sleep","3600"]
>       resources: {limits: {memory: "32Mi"}}
> EOF
> ```
>
> Expect something like:
>
> ```text
> Error from server: error when creating "STDIN": admission webhook "validate.kyverno.svc-fail" denied the request:
>
> resource Pod/default/half-limited was blocked due to the following policies
>
> require-memory-limits:
>   check-memory-limits: Every container must set spec.containers[].resources.limits.memory.
>
> pod/fully-limited created
> ```
>
> The first Pod's first container was perfectly compliant and the Pod was
> rejected anyway. Just as importantly, the message is the one you wrote — not a
> CEL evaluation error — which is the sign the `has()` guards are doing their job.

Note the rejection came from `validate.kyverno.svc-fail` — Kyverno's ordinary validating webhook, with the familiar `resource ... was blocked due to the following policies` framing. This is still a `ClusterPolicy` being enforced by Kyverno in the usual way; only the expression language inside one rule changed. Part 2 introduces two other things that can reject a Pod, each with a visibly different message.

## Section recap

A CEL expression raises an error on a missing field rather than returning null, and under `Enforce` that error denies the request — so a broken rule and a working one are indistinguishable while every test resource happens to be non-compliant. Guard optional fields with `has()`, guarding the whole chain rather than its last link. Guard the rule itself with `operations: [CREATE, UPDATE]`, because `has()` cannot save an expression whose `object` is null on DELETE, and a rule that errors on DELETE makes Pods undeletable cluster-wide.
