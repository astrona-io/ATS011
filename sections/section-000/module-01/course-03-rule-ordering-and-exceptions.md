# Part 3: Rule Ordering and Carving Out Exceptions

## Several policies, one request

Nothing stops two policies from matching the same Pod. In a real cluster that is the normal case — a platform baseline, a security baseline, a team's own namespaced policy, all firing on one `kubectl apply`.

Kyverno does not resolve that by policy name, creation order, or any priority field you can set. It resolves it **by rule type**, in a fixed order:

```text
1. mutate         rewrite the incoming object
2. validate       accept or reject the object as it now stands
3. generate       create downstream resources (asynchronous, after admission)
```

`verifyImages` sits with mutation rather than validation, because a successful verification rewrites the image reference to pin its digest — which is why a failed signature check comes back from `mutate.kyverno.svc-fail` rather than a validating webhook (Section 060).

The consequence worth internalising: **every mutate rule on the cluster finishes before any validate rule starts.** Not every mutate rule *in the same policy* — every mutate rule *anywhere*.

The cheapest way to believe that is to build it in two steps and watch the same command change its answer. Apply a validating policy alone first, then add a mutating policy whose name deliberately sorts *after* it, so that name order would give the wrong result if name order mattered.

> [!TIP]
> **Try it — the same Pod, rejected then admitted**
>
> ```sh
> kubectl apply -f aa-validate-team.yaml
> kubectl -n team-prod run order-a --image=nginx --restart=Never
>
> kubectl apply -f zz-mutate-team.yaml
> kubectl -n team-prod run order-b --image=nginx --restart=Never
> kubectl -n team-prod get pod order-b -o jsonpath='{.metadata.labels}'
> ```
>
> Expect something like:
>
> ```text
> aa-validate-team:
>   require-team-label: 'validation error: A team label is required. rule require-team-label failed at path /metadata/labels/team/'
>
> pod/order-b created
> {"run":"order-b","team":"unassigned"}
> ```
>
> Nothing about the second Pod's manifest differed. A mutate rule merely existed,
> in a *separate* policy named `zz-…`, and the validating rule in `aa-…` stopped
> having anything to object to. Give each policy a moment to report `READY: True`
> before submitting — a policy that has been accepted by the API server is not yet
> a policy Kyverno has wired into its webhook.

This is why the mutate-plus-validate pairing is such a common production shape: the mutate rule supplies a default, the validate rule guarantees the field is present however it got there, and the two never race.

> [!NOTE]
> `generate` is the odd one out. It runs **after** the admission response has already gone back to the client, driven by Kyverno's background controller rather than the webhook. A script that creates a Namespace and immediately expects the generated resource to exist will fail intermittently — not because generation is unreliable, but because `kubectl create ns` returning success says nothing about whether generation has happened yet. Wait for the resource, do not assume it.

## Ordering within one rule type is not defined

Two mutate rules that touch the same field will both run, and the order between *them* is not something you should rely on. If the second overwrites the first, the result depends on evaluation order you do not control.

The fix is not to reason harder about ordering — it is to make the rules not overlap. Narrow one rule's `match`, or gate it with a `preconditions` block that is false whenever the other rule applies. Two rules that can never both fire on the same resource have no ordering problem to solve.

## Exempting something, without weakening the rule

Every real policy eventually meets a resource that legitimately cannot satisfy it — a vendor's Helm chart, a legacy batch job, a control-plane add-on. There are three mechanisms, and choosing between them is mostly a question of *who* should be able to grant the exemption.

**`exclude`** — carved out inside the rule, by the policy author:

```yaml
match:
  any:
    - resources:
        kinds: [Pod]
exclude:
  any:
    - resources:
        namespaces: [kube-system]
```

Best when the exemption is permanent, structural, and belongs to the policy's own definition. It is evaluated as part of resource selection, so an excluded resource is never considered at all — it produces no report entry, not even a `skip`.

**`preconditions`** — a per-resource gate, evaluated after `match` (Section 020):

```yaml
preconditions:
  all:
    - key: "{{ request.object.metadata.labels.tier || '' }}"
      operator: NotEquals
      value: "exempt"
```

Best when the exemption depends on the resource's own data rather than its identity — a label value, an annotation, a field deep in the spec that no selector can reach. A skipped rule *does* appear in reports, as `skip` rather than `pass`, so you keep an audit trail of what was let through and why.

**`PolicyException`** — a separate object, granted to a specific workload without editing the policy at all. This is the mechanism that lets an application team request an exemption through review, rather than requiring a change to a cluster-wide policy.

> [!WARNING]
> **`PolicyException` is disabled by default, and fails silently when it is.** Verified on Kyverno v1.19.1: the admission controller ships with `--enablePolicyException=false`, and with that flag off a `PolicyException` object is **created without any error** — you get at most a deprecation warning about the API version — and is then simply never consulted. The exempted resource keeps getting rejected, with no indication anywhere that an exception exists and is being ignored.
>
> Check the flag before you debug anything else:
>
> ```bash
> kubectl -n kyverno get deploy kyverno-admission-controller \
>   -o jsonpath='{.spec.template.spec.containers[0].args}' | tr ',' '\n' | grep -i exception
> # "--enablePolicyException=false"
> ```
>
> Turning it on is an **install-time** decision — a Helm value or a change to the install manifest — which puts it in the KCA's *Installation, Configuration, and Upgrades* domain rather than this one. Do not try to flip it with an ad-hoc `kubectl patch` that replaces the container's whole `args` array: the admission controller takes around thirty other flags, and dropping them puts it into `CrashLoopBackOff`.

For the Writing Policies domain, the thing to carry is the decision itself: `exclude` for structural exemptions the policy owns, `preconditions` for exemptions that depend on the resource's data, and `PolicyException` for exemptions granted to someone else's workload without touching the policy — subject to the cluster having it enabled at all.

> [!WARNING]
> **Common pitfalls**
>
> - **Assuming policies run in name or creation order.** They do not. Rule *type* decides, and every mutate rule cluster-wide precedes every validate rule.
> - **Expecting a generated resource immediately after the trigger is admitted.** Generation is asynchronous and happens after the response.
> - **Relying on the order of two mutate rules.** Undefined. Make them non-overlapping instead.
> - **Debugging a `PolicyException` that was never enabled.** No error is raised; check the flag first.
> - **Reaching for `exclude` when the exemption depends on a field value.** `exclude` selects on identity — kind, name, namespace, labels. A value buried in the spec needs `preconditions`.

## Section recap

Rule type, not policy name, decides execution order: mutate everywhere, then validate everywhere, then generate asynchronously after the response. Ordering within a type is undefined, so overlapping rules should be made non-overlapping rather than reasoned about. And exemptions come in three forms — `exclude`, `preconditions`, and `PolicyException` — distinguished by whether the exemption is structural, data-dependent, or delegated.
