# Part 1: Deny Rules and the Inversion

## The requirement a pattern cannot state

"A Deployment may not request more than three replicas."

Try to draw that as a `validate.pattern`. You cannot write `replicas: "<=3"` inside a pattern and have it mean what you want across the general case, because a pattern describes the *shape* of an acceptable resource, and "not more than three" is a comparison whose answer depends on a number you have to evaluate rather than a field you can match.

`validate.deny` handles it directly:

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: restrict-replicas
spec:
  validationFailureAction: Enforce
  background: false
  rules:
    - name: max-replicas
      match:
        any:
          - resources:
              kinds:
                - Deployment
      validate:
        message: >-
          Deployments may not request more than 3 replicas;
          this one asks for {{ request.object.spec.replicas }}.
        deny:
          conditions:
            any:
              - key: "{{ request.object.spec.replicas }}"
                operator: GreaterThan
                value: 3
```

Read the `deny` block as a sentence: *deny the request when `replicas` is greater than 3.*

## The inversion, stated plainly

This is where deny rules go wrong, and it is worth saying in the bluntest possible terms:

| Rule body | A true result means |
| :--- | :--- |
| `validate.pattern` | the resource **passes** |
| `validate.deny.conditions` | the resource is **rejected** |

A pattern describes the acceptable state. A deny condition describes the *un*acceptable state. Converting a requirement between the two means negating it — "replicas must be at most 3" becomes "deny when replicas is greater than 3" — and forgetting to negate produces a rule that rejects exactly the resources it was meant to allow.

> [!NOTE]
> Both blocks live under `validate`, which is part of why the confusion persists. They are alternatives, not companions: a rule has `pattern`, `anyPattern`, `deny`, or a `foreach` — one rule body per rule, as always. If you find yourself wanting both in one rule, you want two rules.

Watch the polarity on a real cluster before writing one from scratch.

> [!TIP]
> **Try it — a comparison a pattern could not make**
>
> ```sh
> kubectl apply -f restrict-replicas.yaml
> kubectl -n default create deployment big --image=nginx --replicas=5
> kubectl -n default create deployment small --image=nginx --replicas=2
> ```
>
> Expect something like:
>
> ```text
> restrict-replicas:
>   max-replicas: Deployments may not request more than 3 replicas; this one asks for 5.
>
> deployment.apps/small created
> ```
>
> The condition was true for `big` and it was rejected; false for `small` and it
> was admitted. Note also that the message quotes `5` back — the variable
> resolved against the actual request, so the developer is told what they asked
> for, not just what the limit is.

## `any` and `all` inside conditions

`conditions` takes the same two keys you will meet again in Section 020:

```yaml
deny:
  conditions:
    any:        # reject if AT LEAST ONE of these is true
      - ...
      - ...
```

```yaml
deny:
  conditions:
    all:        # reject only if EVERY one of these is true
      - ...
      - ...
```

Because of the inversion, these read backwards from how they look. `any` is the **stricter** choice — a single true condition is enough to reject. `all` is the **looser** one — every condition has to hold before anything is rejected, so a resource that trips only one of them sails through.

A worked pair makes the difference concrete. "Reject a Pod that runs as root **or** mounts the host network" is `any`: either alone is disqualifying. "Reject a Pod that is in the `sandbox` namespace **and** has no owner annotation" is `all`: being in `sandbox` is fine, missing the annotation is fine, the combination is not.

Getting this backwards is a quieter failure than the pattern/deny inversion, because an `all` block written where `any` was meant still rejects *something* — just far less than intended. Nothing errors; the rule simply under-enforces.

> [!NOTE]
> A bare list of conditions directly under `deny` — with neither `any` nor `all` — is still accepted for backwards compatibility and behaves as `all`. Kyverno's own field documentation flags it as deprecated and slated for removal in a future major release. Write the key explicitly; you will meet the bare form in older policy repositories and should recognise it, but there is no reason to produce more of it.

## Messages that name the value

`message` matters more on a deny rule than on a pattern rule, and for a specific reason: a pattern failure comes with a JSON path (`failed at path /metadata/labels/team/`) that tells the developer where to look. A deny failure has no path — the condition was simply true — so the message is the *only* diagnostic the requester gets.

```yaml
message: >-
  Deployments may not request more than 3 replicas;
  this one asks for {{ request.object.spec.replicas }}.
```

Quoting the offending value back is the difference between a developer fixing their manifest in one attempt and filing a ticket. Compare:

```yaml
# Weak — states a rule, leaves the developer to find the violation
message: "Too many replicas."

# Strong — states the rule, the actual value, and implicitly the fix
message: >-
  Deployments may not request more than 3 replicas;
  this one asks for {{ request.object.spec.replicas }}.
```

The same applies to registry allowlists, label vocabularies, and anything else where the requester's mistake is a *value* rather than a missing field.

> [!WARNING]
> **Common pitfalls**
>
> - **Writing the requirement instead of its negation.** `deny` conditions describe what is *unacceptable*. A rule that denies when `replicas <= 3` rejects every compliant Deployment and admits every oversized one.
> - **Reaching for `all` when you meant `any`.** With deny polarity, `all` is the permissive one. The result is a rule that under-enforces silently.
> - **Leaving the message generic.** A deny failure carries no field path, so a vague message leaves the requester with nothing to act on.
> - **Putting `pattern` and `deny` in one rule.** One rule body per rule; use two rules.

## Section recap

`deny` is validation by comparison rather than by shape, and its conditions describe the unacceptable state rather than the acceptable one. `any` rejects on a single true condition and is the stricter choice; `all` requires every condition and is the looser one. Because a deny failure carries no field path, the message — ideally quoting the offending value — is the requester's only diagnostic.
