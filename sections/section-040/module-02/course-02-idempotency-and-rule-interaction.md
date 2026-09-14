# Part 2: Idempotency and Rule Interaction

## A mutate rule runs more than once

Part 1's mirror rule looks finished. Apply it, create a Pod, and both containers come out correctly prefixed.

Then something updates the Pod — a label, an annotation, anything at all. `match` said `kinds: [Pod]` with no `operations` restriction, so the rule matches that `UPDATE` too, and it runs again against a resource that has *already been mutated*.

> [!TIP]
> **Try it — the same rule, applied twice**
>
> ```sh
> kubectl get pod fe-mutate -o jsonpath='{range .spec.containers[*]}{.name}={.image}{"\n"}{end}'
> kubectl label pod fe-mutate probe=1 --overwrite
> kubectl get pod fe-mutate -o jsonpath='{range .spec.containers[*]}{.name}={.image}{"\n"}{end}'
> ```
>
> Expect something like:
>
> ```text
> app=mirror.local/nginx:1.27
> side=mirror.local/busybox:1.36
>
> pod/fe-mutate labeled
>
> app=mirror.local/mirror.local/nginx:1.27
> side=mirror.local/mirror.local/busybox:1.36
> ```
>
> The label had nothing to do with images. The rule matched the UPDATE anyway,
> read `mirror.local/nginx:1.27` as "the image", and prefixed it again. Nothing
> errored, nothing warned, and the Pod now references an image that does not
> exist.

This is the defining hazard of mutation, and it has no equivalent in validation. A validate rule is a **question**: asking it twice gives the same answer. A mutate rule is a **transformation**: applying it twice gives a different result unless the transformation happens to be idempotent.

Setting a field to a constant is idempotent — `imagePullPolicy: IfNotPresent` applied twice is still `IfNotPresent`. Deriving a new value from the old one generally is not: prefixing, appending, incrementing, and wrapping all compound.

## Making the rule idempotent

The fix is to make the rule a no-op when its work is already done. A `foreach` entry accepts its own `preconditions` block, evaluated per element, which is exactly the right place:

```yaml
mutate:
  foreach:
    - list: "request.object.spec.containers"
      preconditions:
        all:
          - key: "{{ element.image }}"
            operator: NotEquals
            value: "mirror.local/*"
      patchStrategicMerge:
        spec:
          containers:
            - name: "{{ element.name }}"
              image: "mirror.local/{{ element.image }}"
```

Read it as: *for each container, unless its image already starts with `mirror.local/`, prefix it.* An already-prefixed image fails the precondition, that iteration is skipped, and the value is left alone.

Note this is a `preconditions` block **inside the `foreach` entry**, not at rule level. Rule-level preconditions are evaluated once against the whole resource; these are evaluated once per element, against that element. A rule-level guard could only ask "does *any* container need prefixing", which is the wrong question when a Pod has one prefixed container and one that is not.

> [!TIP]
> **Try it — a guarded rule leaves finished work alone**
>
> ```sh
> kubectl apply -f prefix-once.yaml
>
> kubectl apply -f - <<'EOF'
> apiVersion: v1
> kind: Pod
> metadata: {name: fe-once}
> spec:
>   containers:
>     - {name: app, image: "nginx:1.27"}
>     - {name: already, image: "mirror.local/redis:7"}
> EOF
>
> kubectl get pod fe-once -o jsonpath='{range .spec.containers[*]}{.name}={.image}{"\n"}{end}'
> ```
>
> Expect something like:
>
> ```text
> app=mirror.local/nginx:1.27
> already=mirror.local/redis:7
> ```
>
> One container was prefixed, the other left exactly as submitted — in the same
> Pod, in the same pass. That per-element granularity is what a rule-level
> precondition could not have given you.

The second, complementary defence is to restrict the operations the rule matches at all:

```yaml
match:
  any:
    - resources:
        kinds:
          - Pod
        operations:
          - CREATE
```

If the transformation genuinely only makes sense at creation time, that removes the re-application path entirely. Use both where both apply: `operations` narrows *when* the rule runs, the precondition guarantees the result *if* it runs. A rule that is safe under repetition is safe regardless of what triggers it, which matters because `mutateExistingOnPolicyUpdate` (Module 1) re-runs a rule on a schedule you did not initiate.

## Two rules on one field

Ordering *between* rule types is fixed and reliable: every mutate rule finishes before any validate rule. Ordering *within* mutation is not defined. Two mutate rules that both write `spec.containers[*].image` will both run, and which one wins is not something to build on.

The instinct is to look for a priority field. There isn't one, and the absence is deliberate — an ordering knob would invite policies that only work in a particular arrangement, which is fragile in a cluster where anyone may add a policy tomorrow.

The durable fix is to make the rules non-overlapping, and there are two ways:

* **Narrow the `match`.** If one rule governs images and another governs a different field, they never collide. If both genuinely govern images, they probably want to be one rule.
* **Guard with preconditions.** Give each rule a condition that is false whenever the other applies. Two rules that can never both fire on one resource have no ordering to resolve.

The same reasoning applies to a mutate rule and a validate rule that disagree — except there the ordering *is* defined, and the mutate rule always wins by getting there first. Module 1 showed that with a validate rule that never saw a missing label because a mutate rule in a different policy had already supplied it. That is a feature when it is intentional and a trap when it is not: a validate rule cannot enforce anything a mutate rule has already made true.

> [!WARNING]
> **Common pitfalls**
>
> - **Assuming a mutate rule runs only at creation.** It runs on every matching operation, including UPDATEs that have nothing to do with the field it touches.
> - **Writing a transformation that compounds.** Prefixing, appending, and wrapping are not idempotent; setting a constant is.
> - **Putting the guard at rule level when the work is per element.** A rule-level precondition cannot distinguish one container from another.
> - **Relying on the order of two mutate rules.** Undefined. Make them non-overlapping.
> - **Expecting a validate rule to catch what a mutate rule fixed.** Mutation runs first, so the validation sees the corrected object.

## Section recap

Mutate rules re-run on UPDATE, so any transformation that derives a new value from an old one must be made idempotent or it compounds — visibly, silently, and in a way no error reports. A `preconditions` block inside the `foreach` entry provides the per-element guard; `operations: [CREATE]` removes the re-application path where that is appropriate. Ordering between mutate rules is undefined and should be designed away rather than reasoned about.
