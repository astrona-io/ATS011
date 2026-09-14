# Part 1: Policy Objects and Rule Anatomy

Every other section of this course teaches a rule type. This part is about the object those rules live inside, and about the fields every rule carries regardless of what kind of rule it is. Both are decided before any rule body runs, and both are easy to skip past when you learn rule types one at a time.

## Two kinds, one spec

Kyverno ships two policy kinds, and they share an identical `spec`:

| Kind | Scope | Governs |
| :--- | :--- | :--- |
| `ClusterPolicy` | cluster-scoped | matching resources in **every** namespace, plus cluster-scoped resources |
| `Policy` | namespaced | matching resources in **its own namespace only** |

Because the `spec` is the same, you can take any `ClusterPolicy` in this course, change `kind` to `Policy`, add a `metadata.namespace`, and it is a valid policy — with a much smaller blast radius.

```yaml
apiVersion: kyverno.io/v1
kind: Policy
metadata:
  name: require-team-label
  namespace: team-staging
spec:
  validationFailureAction: Enforce
  background: false
  rules:
    - name: check-team-label
      match:
        any:
          - resources:
              kinds:
                - Pod
      validate:
        message: "A team label is required on every Pod in this namespace."
        pattern:
          metadata:
            labels:
              team: "?*"
```

The `match` block here says `kinds: [Pod]` with no namespace restriction at all — and it still only governs `team-staging`. That is the part worth internalising: **a namespaced `Policy` cannot be widened by its own `match` block.** Scope is decided by the object's kind and namespace, before any rule is consulted.

Verify that rather than trusting it, since "my rule says all Pods and it isn't catching them" is a common first confusion.

> [!TIP]
> **Try it — the same rule, two namespaces, one verdict**
>
> ```sh
> kubectl apply -f namespaced-policy.yaml
> kubectl get policy -A
> kubectl -n team-staging run ns-bad --image=nginx --restart=Never
> kubectl -n team-prod run ns-bad --image=nginx --restart=Never
> ```
>
> Expect something like:
>
> ```text
> policy.kyverno.io/require-team-label created
>
> NAMESPACE      NAME                 ADMISSION   BACKGROUND   READY   AGE   MESSAGE
> team-staging   require-team-label   true        false        True    10s   Ready
>
> require-team-label:
>   check-team-label: 'validation error: A team label is required on every Pod in this namespace. rule check-team-label failed at path /metadata/labels/team/'
>
> pod/ns-bad created
> ```
>
> Identical Pods, opposite outcomes. Note also that `kubectl get policy` needs
> `-A` or a namespace — unlike `clusterpolicy`, these objects live somewhere.

Which to reach for is a question about ownership. A platform team writing a baseline every namespace must satisfy wants `ClusterPolicy`. An application team hardening their own namespace — without needing cluster-admin, and without being able to affect anyone else — wants `Policy`. The second case is why `Policy` exists at all: it delegates policy authorship safely.

> [!NOTE]
> A namespaced `Policy` also cannot govern **cluster-scoped resources** — `Namespace`, `ClusterRole`, `PersistentVolume`, or a CRD's cluster-scoped kinds. There is no namespace for such a resource to belong to, so no namespaced policy can select it. A `generate` rule triggered by `kind: Namespace` (Section 050) therefore has to be a `ClusterPolicy`, regardless of where the generated resource lands.

## What every rule has, whatever its type

Whichever rule type you are writing, the same skeleton surrounds it:

```yaml
rules:
  - name: <required, unique within the policy>
    match:      # which resources this rule considers
    exclude:    # carved out of match, evaluated after it
    preconditions:   # a per-resource yes/no gate (Section 020)
    context:    # data fetched before the rule body runs (Section 070)
    <validate | mutate | generate | verifyImages>:   # exactly one rule body
```

Three points that catch people out:

* **`name` is required and must be unique within the policy.** It is also what appears in a rejection message, so it is the only label a developer has for "which rule stopped me" — `check-team-label` tells them something, `rule-1` does not.
* **Exactly one rule body per rule.** A single rule cannot both mutate and validate. Wanting both means writing two rules, which is normal and common.
* **`match` with no entries matches nothing.** Kyverno never treats an empty `match` as "everything" — a rule that selects nothing is a no-op rather than a cluster-wide blanket.

## Where each decision is made

It helps to see the order these fields are consulted in, because they are often discussed as if they were one filter when they are four, applied at different moments and at different cost.

```text
  request arrives
        |
  [1] policy scope        object kind + namespace       <- not a rule field at all
        |                 a namespaced Policy stops here for out-of-namespace resources
        v
  [2] match / exclude     kind, namespace, name, labels <- selector-shaped, cheap
        |
        v
  [3] context             apiCall / configMap / ...     <- fetched for every surviving request
        |
        v
  [4] preconditions       any JMESPath over the request <- per-resource, arbitrary
        |
        v
      rule body           validate | mutate | generate | verifyImages
```

Two consequences fall out of that ordering. Scope is not something a rule can influence, which is why the namespaced-`Policy` confusion above is so persistent — the rule genuinely says "all Pods" and is genuinely limited to one namespace. And `context` is fetched *before* `preconditions` are evaluated, so a precondition cannot save you a lookup; only narrowing `match` does that.


## Section recap

`ClusterPolicy` and `Policy` share an identical spec and differ only in reach — and that reach is fixed by the object's kind and namespace before any rule is consulted, so a namespaced policy cannot be widened by its own `match` block, nor reach a cluster-scoped resource at all. Every rule, whatever its type, carries `name`, `match`, `exclude`, `preconditions`, and `context` around exactly one rule body.
