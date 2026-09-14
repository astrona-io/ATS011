# Part 2: Failure Actions and Staged Rollout

Part 1 settled which resources a rule considers. This part settles what happens to one that fails — which is a separate decision, made at up to three different levels, and the one that determines whether a new rule is an outage or a report.

## Enforce and Audit, at two different levels

`validationFailureAction` sits at policy level and governs every validate rule in the policy:

* **`Enforce`** — the request is rejected. The developer sees an error, nothing is created.
* **`Audit`** — the request is admitted and the violation is recorded in a `PolicyReport`.

Newer Kyverno versions also expose `failureAction` **inside each rule's `validate` block**, which is what you want when one policy holds rules at different maturities — some ready to block, some still being tuned:

```yaml
spec:
  background: false
  rules:
    - name: enforced-team-label
      match:
        any:
          - resources: { kinds: [Pod] }
      validate:
        failureAction: Enforce
        message: "ENFORCED: a team label is required."
        pattern:
          metadata:
            labels:
              team: "?*"
    - name: audited-owner-label
      match:
        any:
          - resources: { kinds: [Pod] }
      validate:
        failureAction: Audit
        message: "AUDITED: an owner label is recommended."
        pattern:
          metadata:
            labels:
              owner: "?*"
```

Submit a Pod that satisfies the first rule and violates the second, then one that violates both, and the independence becomes obvious.

> [!TIP]
> **Try it — two rules, two different consequences, one policy**
>
> ```sh
> kubectl apply -f mixed-actions.yaml
> kubectl -n team-prod run mixed-a --image=nginx --restart=Never --labels=team=platform
> kubectl -n team-prod run mixed-b --image=nginx --restart=Never
> ```
>
> Expect something like:
>
> ```text
> pod/mixed-a created
>
> mixed-actions:
>   enforced-team-label: 'validation error: ENFORCED: a team label is required. rule enforced-team-label failed at path /metadata/labels/team/'
> ```
>
> `mixed-a` has no `owner` label and was admitted anyway — the audited rule
> recorded it and did not block. `mixed-b` violates both rules, and only the
> **enforced** one appears in the rejection. The audited failure is in the
> reports, not in the error.

That last detail is worth keeping: a rejection message lists the rules that *blocked* the request, not every rule that failed. If you are diagnosing from the error alone, you are seeing a filtered view.

## Rolling a rule out namespace by namespace

The usual way to introduce a new rule is `Audit` everywhere, read the reports, fix what surfaces, then flip to `Enforce`. That is a cluster-wide switch, and on a large cluster it is an uncomfortably big one.

`validationFailureActionOverrides` makes the switch per-namespace instead. The policy sets a default action and then names exceptions:

```yaml
spec:
  validationFailureAction: Audit
  validationFailureActionOverrides:
    - action: Enforce
      namespaces:
        - team-prod
  background: false
  rules:
    - name: check-team-label
      match:
        any:
          - resources: { kinds: [Pod] }
      validate:
        message: "A team label is required on every Pod."
        pattern:
          metadata:
            labels:
              team: "?*"
```

Read it as: audit by default, but in `team-prod` actually block. That inverts the usual rollout — instead of enforcing everywhere at once when you are finally confident, you enforce in one namespace, learn, and widen the list.

> [!TIP]
> **Try it — one policy, two namespaces, two behaviours**
>
> ```sh
> kubectl apply -f overrides-policy.yaml
> kubectl -n team-prod run no-label --image=nginx --restart=Never
> kubectl -n team-staging run no-label --image=nginx --restart=Never
> ```
>
> Expect something like:
>
> ```text
> require-team-label:
>   check-team-label: 'validation error: A team label is required on every Pod. rule check-team-label failed at path /metadata/labels/team/'
>
> pod/no-label created
> ```
>
> Same policy, same rule, same Pod spec. `team-prod` blocks because the override
> applies there; `team-staging` falls back to the policy's `Audit` default and
> admits it.

The `namespaces` list accepts globs, so `team-*` or `*-prod` work as you would expect — which is how this scales past naming one namespace at a time.

> [!WARNING]
> **Common pitfalls**
>
> - **Assuming a namespaced `Policy` can be widened by `match`.** It cannot. Scope comes from the object, not the rule.
> - **Expecting `Audit` to protect anything.** It records, it never blocks. A cluster with every policy on `Audit` has policy *reporting*, not policy *enforcement*.
> - **Reading a rejection message as a complete list of failures.** Only blocking rules appear there; audited failures are in the reports.
> - **Thinking `Enforce` reaches backwards.** It governs admission only. Resources that already existed when the policy landed are untouched by it — that is what background scanning (Section 030) is for.

## Section recap

`validationFailureAction` sets the consequence for a whole policy and `failureAction` sets it per rule, which is what lets one policy hold a rule you are ready to block on alongside one you are still tuning. A rejection message lists only the rules that *blocked* the request, so audited failures are invisible there and live in reports instead. And `validationFailureActionOverrides` moves the Enforce decision to per-namespace granularity, which inverts the usual rollout: enforce in one namespace, learn, then widen the list.
